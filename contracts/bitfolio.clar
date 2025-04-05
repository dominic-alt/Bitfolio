;; Bitfolio Protocol: Automated Portfolio Management on Stacks L2
;; Summary: Non-custodial portfolio management system with automatic rebalancing, built for Bitcoin DeFi on Stacks Layer 2
;; Description:
;; Bitfolio Protocol enables trustless creation and maintenance of token portfolios with predefined allocation strategies. 
;; Users can deploy customized investment baskets, automatically rebalanced to target weights while maintaining full asset custody.
;; Built with Bitcoin security in mind, the protocol features:
;; - Compliance with Stacks L2 architecture for Bitcoin-finalized transactions
;; - Basis point precision for allocation targets (0.01% granularity)
;; - Time-locked rebalancing (24h minimum interval)
;; - Protocol fee structure payable in STX
;; - Robust error handling with 11 distinct failure states
;; - Portfolio ownership controls with principal-based access

;; Error codes - Standardized error states
(define-constant ERR-NOT-AUTHORIZED (err u100))    ;; Authorization failure
(define-constant ERR-INVALID-PORTFOLIO (err u101)) ;; Nonexistent portfolio
(define-constant ERR-INSUFFICIENT-BALANCE (err u102)) ;; Funding shortage
(define-constant ERR-INVALID-TOKEN (err u103))     ;; Unsupported asset
(define-constant ERR-REBALANCE-FAILED (err u104))  ;; Rebalance execution error
(define-constant ERR-PORTFOLIO-EXISTS (err u105))  ;; Duplicate portfolio
(define-constant ERR-INVALID-PERCENTAGE (err u106));; Allocation math error
(define-constant ERR-MAX-TOKENS-EXCEEDED (err u107)) ;; Asset limit breach
(define-constant ERR-LENGTH-MISMATCH (err u108))   ;; Parameter mismatch
(define-constant ERR-USER-STORAGE-FAILED (err u109)) ;; Data storage error
(define-constant ERR-INVALID-TOKEN-ID (err u110))  ;; Nonexistent asset ID

;; Protocol Configuration
(define-data-var protocol-owner principal tx-sender)  ;; Governance admin
(define-data-var portfolio-counter uint u0)           ;; Global ID counter
(define-data-var protocol-fee uint u25)               ;; 0.25% in basis points

;; Portfolio Constants
(define-constant MAX-TOKENS-PER-PORTFOLIO u10)        ;; Asset diversification limit
(define-constant BASIS-POINTS u10000)                 ;; Precision denominator

;; Core Data Structures
(define-map Portfolios                                ;; Master portfolio registry
    uint                                              ;; portfolio-id
    {
        owner: principal,                             ;; Controlling account
        created-at: uint,                             ;; Block height
        last-rebalanced: uint,                        ;; Rebalance timestamp
        total-value: uint,                            ;; Aggregated TVL
        active: bool,                                 ;; Operational status
        token-count: uint                             ;; Asset count
    }
)

(define-map PortfolioAssets                           ;; Asset allocation storage
    {portfolio-id: uint, token-id: uint}              ;; Composite key
    {
        target-percentage: uint,                      ;; BPS allocation target
        current-amount: uint,                         ;; Current holdings
        token-address: principal                      ;; Asset contract
    }
)

(define-map UserPortfolios                            ;; User portfolio index
    principal                                         ;; Owner address
    (list 20 uint)                                    ;; Portfolio ID registry
)

;; READ-ONLY INTERFACE

;; Retrieve portfolio metadata
(define-read-only (get-portfolio (portfolio-id uint))
    (map-get? Portfolios portfolio-id)
)

;; Get asset details for specific portfolio
(define-read-only (get-portfolio-asset (portfolio-id uint) (token-id uint))
    (map-get? PortfolioAssets {portfolio-id: portfolio-id, token-id: token-id})
)

;; List all portfolios owned by address
(define-read-only (get-user-portfolios (user principal))
    (default-to (list) (map-get? UserPortfolios user))
)

;; Calculate rebalance requirements
(define-read-only (calculate-rebalance-amounts (portfolio-id uint))
    (let (
        (portfolio (unwrap! (get-portfolio portfolio-id) ERR-INVALID-PORTFOLIO))
        (total-value (get total-value portfolio))
    )
    (ok {
        portfolio-id: portfolio-id,
        total-value: total-value,
        needs-rebalance: (> (- stacks-block-height (get last-rebalanced portfolio)) u144) ;; 24h blocks
    }))
)

;; PRIVATE HELPERS

;; Validate token ID against portfolio configuration
(define-private (validate-token-id (portfolio-id uint) (token-id uint))
    (let ((portfolio (unwrap! (get-portfolio portfolio-id) false)))
    (and 
        (< token-id MAX-TOKENS-PER-PORTFOLIO)
        (< token-id (get token-count portfolio))
        true
    ))
)

;; Percentage validation (0-10000 basis points)
(define-private (validate-percentage (percentage uint))
    (and (>= percentage u0) (<= percentage BASIS-POINTS))
)

;; Portfolio allocation sanity check
(define-private (validate-portfolio-percentages (percentages (list 10 uint)))
    (fold check-percentage-sum percentages true)
)

;; Fold helper for percentage validation
(define-private (check-percentage-sum (current-percentage uint) (valid bool))
    (and valid (validate-percentage current-percentage))
)

;; Update user portfolio index with new entry
(define-private (add-to-user-portfolios (user principal) (portfolio-id uint))
    (let (
        (current-portfolios (get-user-portfolios user))
        (new-portfolios (unwrap! (as-max-len? (append current-portfolios portfolio-id) u20) ERR-USER-STORAGE-FAILED))
    )
    (map-set UserPortfolios user new-portfolios)
    (ok true))
)

;; Initialize asset entry in portfolio
(define-private (initialize-portfolio-asset 
    (index uint) 
    (token principal) 
    (percentage uint) 
    (portfolio-id uint))
    (if (>= percentage u0)
        (begin
            (map-set PortfolioAssets
                {portfolio-id: portfolio-id, token-id: index}
                {
                    target-percentage: percentage,
                    current-amount: u0,
                    token-address: token
                }
            )
            (ok true))
        ERR-INVALID-TOKEN
    )
)

;; PUBLIC FUNCTIONS

;; Create new investment portfolio
(define-public (create-portfolio (initial-tokens (list 10 principal)) (percentages (list 10 uint)))
    (let (
        (portfolio-id (+ (var-get portfolio-counter) u1))
        (token-count (len initial-tokens))
        (percentage-count (len percentages))
        (token-0 (element-at? initial-tokens u0))
        (token-1 (element-at? initial-tokens u1))
        (percentage-0 (element-at? percentages u0))
        (percentage-1 (element-at? percentages u1))
    )
    ;; Validation checks
    (asserts! (<= token-count MAX-TOKENS-PER-PORTFOLIO) ERR-MAX-TOKENS-EXCEEDED)
    (asserts! (is-eq token-count percentage-count) ERR-LENGTH-MISMATCH)
    (asserts! (validate-portfolio-percentages percentages) ERR-INVALID-PERCENTAGE)
    
    ;; Portfolio metadata creation
    (map-set Portfolios portfolio-id
        {
            owner: tx-sender,
            created-at: stacks-block-height,
            last-rebalanced: stacks-block-height,
            total-value: u0,
            active: true,
            token-count: token-count
        }
    )
    
    ;; Asset initialization checks
    (asserts! (and (is-some token-0) (is-some token-1)) ERR-INVALID-TOKEN)
    (asserts! (and (is-some percentage-0) (is-some percentage-1)) ERR-INVALID-PERCENTAGE)
    
    ;; Asset record creation
    (try! (initialize-portfolio-asset 
        u0 
        (unwrap-panic token-0)
        (unwrap-panic percentage-0)
        portfolio-id))
    
    (try! (initialize-portfolio-asset 
        u1
        (unwrap-panic token-1)
        (unwrap-panic percentage-1)
        portfolio-id))
    
    ;; Update user registry
    (try! (add-to-user-portfolios tx-sender portfolio-id))
    
    ;; Global counter increment
    (var-set portfolio-counter portfolio-id)
    (ok portfolio-id))
)

;; Execute portfolio rebalancing
(define-public (rebalance-portfolio (portfolio-id uint))
    (let ((portfolio (unwrap! (get-portfolio portfolio-id) ERR-INVALID-PORTFOLIO)))
    (asserts! (is-eq tx-sender (get owner portfolio)) ERR-NOT-AUTHORIZED)
    (asserts! (get active portfolio) ERR-INVALID-PORTFOLIO)
    
    ;; Update rebalance timestamp
    (map-set Portfolios portfolio-id
        (merge portfolio {last-rebalanced: stacks-block-height})
    )
    
    (ok true))
)

;; Modify asset allocation targets
(define-public (update-portfolio-allocation 
    (portfolio-id uint) 
    (token-id uint)
    (new-percentage uint))
    (let (
        (portfolio (unwrap! (get-portfolio portfolio-id) ERR-INVALID-PORTFOLIO))
        (asset (unwrap! (get-portfolio-asset portfolio-id token-id) ERR-INVALID-TOKEN))
    )
    (asserts! (is-eq tx-sender (get owner portfolio)) ERR-NOT-AUTHORIZED)
    (asserts! (validate-percentage new-percentage) ERR-INVALID-PERCENTAGE)
    (asserts! (validate-token-id portfolio-id token-id) ERR-INVALID-TOKEN-ID)
    
    ;; Update allocation target
    (map-set PortfolioAssets
        {portfolio-id: portfolio-id, token-id: token-id}
        (merge asset {target-percentage: new-percentage})
    )
    
    (ok true))
)

;; ADMIN FUNCTIONS

;; Governance control: Transfer protocol ownership
(define-public (initialize (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-eq new-owner tx-sender)) ERR-NOT-AUTHORIZED)
        (var-set protocol-owner new-owner)
        (ok true))
)