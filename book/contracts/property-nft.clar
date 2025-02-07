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
        created-at: uint,
        last-price-update: uint,
        description: (optional (string-utf8 1024)),
        features: (list 10 (string-utf8 64))
    }
)

;; Track total properties and property ids
(define-data-var last-property-id uint u0)
(define-map property-count principal uint)

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
(define-constant err-too-many-features (err u108))
(define-constant err-invalid-description (err u109))

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

;; Check that an optional description is valid.
(define-private (is-valid-description (desc (optional (string-utf8 1024))))
    (match desc d (<= (len d) u1024) true)
)

(define-private (is-valid-recipient (recipient principal))
    (and
        (not (is-eq recipient tx-sender))
        (not (is-eq recipient (as-contract tx-sender)))
    )
)

(define-private (increment-property-count (owner principal))
    (match (map-get? property-count owner)
        count (map-set property-count owner (+ count u1))
        (map-set property-count owner u1)
    )
)

(define-private (decrement-property-count (owner principal))
    (match (map-get? property-count owner)
        count (if (> count u0)
            (map-set property-count owner (- count u1))
            (map-delete property-count owner))
        false
    )
)

;; Administrative Functions
(define-public (set-property-metadata
    (location (string-utf8 256))
    (price uint)
    (description (optional (string-utf8 1024)))
    (features (list 10 (string-utf8 64))))
    (let
        ((new-id (+ (var-get last-property-id) u1)))
        (begin
            (asserts! (is-valid-price price) err-invalid-price)
            (asserts! (is-valid-location location) err-invalid-location)
            (asserts! (<= (len features) u10) err-too-many-features)
            (asserts! (is-valid-description description) err-invalid-description)
            
            (try! (nft-mint? property new-id tx-sender))
            (var-set last-property-id new-id)
            
            (map-set property-metadata
                new-id
                {
                    owner: tx-sender,
                    location: location,
                    price: price,
                    status: u"AVAILABLE",
                    created-at: block-height,
                    last-price-update: block-height,
                    description: description,
                    features: features
                }
            )
            
            (increment-property-count tx-sender)
            (ok new-id)
        )
    )
)

;; Price Management
(define-public (update-price (property-id uint) (new-price uint))
    (begin
        (asserts! (is-valid-property property-id) err-invalid-property)
        (asserts! (is-owner property-id tx-sender) err-unauthorized)
        (asserts! (is-valid-price new-price) err-invalid-price)
        
        (match (map-get? property-metadata property-id)
            metadata (begin
                (map-set property-metadata
                    property-id
                    (merge metadata { 
                        price: new-price,
                        last-price-update: block-height
                    })
                )
                (ok true)
            )
            err-not-found
        )
    )
)

;; Property Management
(define-public (update-features 
    (property-id uint) 
    (new-features (list 10 (string-utf8 64))))
    (begin
        (asserts! (is-valid-property property-id) err-invalid-property)
        (asserts! (is-owner property-id tx-sender) err-unauthorized)
        (asserts! (<= (len new-features) u10) err-too-many-features)
        
        (match (map-get? property-metadata property-id)
            metadata (begin
                (map-set property-metadata
                    property-id
                    (merge metadata { features: new-features })
                )
                (ok true)
            )
            err-not-found
        )
    )
)

;; Read Functions
(define-read-only (get-property-metadata (property-id uint))
    (match (map-get? property-metadata property-id)
        metadata (ok metadata)
        err-not-found
    )
)

(define-read-only (get-property-count (owner principal))
    (ok (default-to u0 (map-get? property-count owner)))
)

;; SIP009 NFT Implementation
(define-public (transfer (id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-valid-property id) err-invalid-property)
        (asserts! (is-owner id sender) err-unauthorized)
        (asserts! (is-eq tx-sender sender) err-owner-only)
        (asserts! (is-valid-recipient recipient) err-invalid-recipient)
        
        (try! (nft-transfer? property id sender recipient))
        
        (match (map-get? property-metadata id)
            metadata (begin
                (map-set property-metadata
                    id
                    (merge metadata { owner: recipient })
                )
                (decrement-property-count sender)
                (increment-property-count recipient)
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

;; Updated get-last-token-id to match trait's specification (response uint uint)
(define-read-only (get-last-token-id)
    (ok (var-get last-property-id))
)

(define-public (get-token-uri (token-id uint))
    (ok none)
)
