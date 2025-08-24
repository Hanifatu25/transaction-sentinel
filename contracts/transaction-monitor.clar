;; transaction-sentinel
;; 
;; A smart contract for comprehensive transaction tracking and access control
;; on the Stacks blockchain, providing robust data management and verification.

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-INPUT (err u103))
(define-constant ERR-INVALID-TRANSACTION (err u104))
(define-constant ERR-TRANSACTION-NOT-TRACKED (err u105))
(define-constant ERR-NOT-VERIFIER (err u107))

;; Data storage

;; Transaction registry
(define-map transactions
  { transaction-id: uint }
  {
    sender: principal,
    recipient: principal,
    amount: uint,
    token-type: (string-ascii 50),
    timestamp: uint,
    status: (string-ascii 20), ;; "pending", "completed", "cancelled"
    additional-data: (string-ascii 255)
  }
)

;; Transaction verifier registry
(define-map verifiers
  { verifier: principal }
  {
    name: (string-ascii 100),
    verification-type: (string-ascii 100),
    registration-date: uint,
    active: bool
  }
)

;; Transaction verification records
(define-map verifications
  { verification-id: uint }
  {
    verifier: principal,
    transaction-id: uint,
    verification-date: uint,
    status: (string-ascii 20), ;; "verified", "rejected", "pending"
    comments: (string-ascii 255)
  }
)

;; Data access control
(define-map data-access-control
  { data-type: (string-ascii 20), data-id: uint, accessor: principal }
  { 
    granted-by: principal,
    granted-at: uint,
    access-level: (string-ascii 20) ;; "full", "limited", "metadata-only"
  }
)

;; Counter variables for IDs
(define-data-var next-transaction-id uint u1)
(define-data-var next-verification-id uint u1)

;; Private functions

;; Generate a new transaction ID
(define-private (generate-transaction-id)
  (let ((current-id (var-get next-transaction-id)))
    (var-set next-transaction-id (+ current-id u1))
    current-id
  )
)

;; Generate a new verification ID
(define-private (generate-verification-id)
  (let ((current-id (var-get next-verification-id)))
    (var-set next-verification-id (+ current-id u1))
    current-id
  )
)

;; Check if a principal is a registered verifier
(define-private (is-registered-verifier (verifier principal))
  (default-to false (get active (map-get? verifiers { verifier: verifier })))
)

;; Read-only functions

;; Get transaction information
(define-read-only (get-transaction-info (transaction-id uint))
  (map-get? transactions { transaction-id: transaction-id })
)

;; Get verifier information
(define-read-only (get-verifier-info (verifier principal))
  (map-get? verifiers { verifier: verifier })
)

;; Public functions

;; Register a new transaction
(define-public (register-transaction 
    (recipient principal) 
    (amount uint) 
    (token-type (string-ascii 50)) 
    (status (string-ascii 20)) 
    (additional-data (string-ascii 255)))
  (let ((sender tx-sender)
        (transaction-id (generate-transaction-id)))
    (begin
      (map-set transactions
        { transaction-id: transaction-id }
        {
          sender: sender,
          recipient: recipient,
          amount: amount,
          token-type: token-type,
          timestamp: block-height,
          status: status,
          additional-data: additional-data
        }
      )
      (ok transaction-id)
    )
  )
)

;; Register as a transaction verifier
(define-public (register-verifier (name (string-ascii 100)) (verification-type (string-ascii 100)))
  (let ((verifier tx-sender))
    (if (is-registered-verifier verifier)
      ERR-ALREADY-EXISTS
      (begin
        (map-set verifiers
          { verifier: verifier }
          {
            name: name,
            verification-type: verification-type,
            registration-date: block-height,
            active: true
          }
        )
        (ok true)
      )
    )
  )
)

;; Submit a verification attestation for a transaction
(define-public (submit-verification 
    (transaction-id uint) 
    (status (string-ascii 20)) 
    (comments (string-ascii 255)))
  (let ((verifier tx-sender)
        (verification-id (generate-verification-id)))
    (if (not (is-registered-verifier verifier))
      ERR-NOT-VERIFIER
      (match (map-get? transactions { transaction-id: transaction-id })
        transaction-data (begin
          (map-set verifications
            { verification-id: verification-id }
            {
              verifier: verifier,
              transaction-id: transaction-id,
              verification-date: block-height,
              status: status,
              comments: comments
            }
          )
          (ok verification-id)
        )
        ERR-TRANSACTION-NOT-TRACKED
      )
    )
  )
)

;; Update transaction status
(define-public (update-transaction-status 
    (transaction-id uint) 
    (status (string-ascii 20)))
  (match (map-get? transactions { transaction-id: transaction-id })
    transaction-data (begin
      (map-set transactions
        { transaction-id: transaction-id }
        (merge transaction-data { status: status })
      )
      (ok true)
    )
    ERR-TRANSACTION-NOT-TRACKED
  )
)

;; Grant data access to another principal
(define-public (grant-data-access 
    (data-type (string-ascii 20)) 
    (data-id uint) 
    (accessor principal) 
    (access-level (string-ascii 20)))
  (let ((granter tx-sender))
    (if (is-eq data-type "transaction")
      (match (map-get? transactions { transaction-id: data-id })
        transaction-data 
          (if (is-eq (get sender transaction-data) granter)
            (begin
              (map-set data-access-control
                { data-type: data-type, data-id: data-id, accessor: accessor }
                { granted-by: granter, granted-at: block-height, access-level: access-level }
              )
              (ok true)
            )
            ERR-NOT-AUTHORIZED
          )
        ERR-TRANSACTION-NOT-TRACKED
      )
      ERR-INVALID-INPUT
    )
  )
)

;; Revoke previously granted data access
(define-public (revoke-data-access (data-type (string-ascii 20)) (data-id uint) (accessor principal))
  (let ((revoker tx-sender))
    (match (map-get? data-access-control { data-type: data-type, data-id: data-id, accessor: accessor })
      access-data
        (if (is-eq (get granted-by access-data) revoker)
          (begin
            (map-delete data-access-control { data-type: data-type, data-id: data-id, accessor: accessor })
            (ok true)
          )
          ERR-NOT-AUTHORIZED
        )
      ERR-NOT-FOUND
    )
  )
)