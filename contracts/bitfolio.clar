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