;; property-nft.clar
;; NFT implementation for real estate properties

;; Import local NFT trait
(use-trait nft-trait .nft-trait.nft-trait)

(impl-trait .nft-trait.nft-trait)

(define-non-fungible-token property uint)

;; Storage for property metadata
(define-map property-metadata
    uint
    {
        owner: principal,
        location: (string-utf8 256),
        price: uint,
        status: (string-utf8 20),
        created-at: uint
    }
)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-status (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-invalid-property (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-invalid-location (err u106))
(define-constant err-invalid-recipient (err u107))

;; Internal Functions
(define-private (is-valid-price (price uint))
    (> price u0)
)

(define-private (is-valid-property (property-id uint))
    (is-some (map-get? property-metadata property-id))
)

(define-private (is-owner (property-id uint) (user principal))
    (match (map-get? property-metadata property-id)
        metadata (is-eq (get owner metadata) user)
        false
    )
)

(define-private (is-valid-location (location (string-utf8 256)))
    (and 
        (not (is-eq location u""))
        (<= (len location) u256)
    )
)

(define-private (is-valid-recipient (recipient principal))
    (and
        (not (is-eq recipient tx-sender))
        (not (is-eq recipient (as-contract tx-sender)))
    )
)

;; Administrative Functions
(define-public (set-property-metadata
    (property-id uint)
    (location (string-utf8 256))
    (price uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-valid-price price) err-invalid-price)
        (asserts! (is-valid-location location) err-invalid-location)
        (asserts! (not (is-valid-property property-id)) err-invalid-property) ;; Ensure property doesn't exist
        
        (try! (nft-mint? property property-id contract-owner))
        
        (map-set property-metadata
            property-id
            {
                owner: contract-owner,
                location: location,
                price: price,
                status: u"AVAILABLE",
                created-at: block-height
            }
        )
        (ok true)
    )
)

;; Read Functions
(define-read-only (get-property-metadata (property-id uint))
    (match (map-get? property-metadata property-id)
        metadata (ok metadata)
        err-not-found
    )
)

;; Required by NFT trait
(define-public (get-token-uri (token-id uint))
    (ok none)
)

;; SIP009 NFT Trait Implementation
(define-public (transfer (id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-valid-property id) err-invalid-property)
        (asserts! (is-owner id sender) err-unauthorized)
        (asserts! (is-eq tx-sender sender) err-owner-only)
        (asserts! (is-valid-recipient recipient) err-invalid-recipient)
        
        (try! (nft-transfer? property id sender recipient))
        
        ;; Update metadata ownership
        (match (map-get? property-metadata id)
            metadata (begin
                (map-set property-metadata
                    id
                    (merge metadata { owner: recipient })
                )
                (ok true)
            )
            err-not-found
        )
    )
)

(define-public (get-owner (id uint))
    (begin
        (asserts! (is-valid-property id) err-invalid-property)
        (ok (nft-get-owner? property id))
    )
)

(define-public (get-last-token-id)
    (ok u0)
)
