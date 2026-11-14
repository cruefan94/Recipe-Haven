# Ingredient finder — optional retailer product feed

A store map/directory does not have reliable product stock or prices. Recipe Haven lists the stores within 30 km using GPS and OpenStreetMap by default. To show product-specific listings, configure a server-side HTTPS adapter using a legal, permissioned retailer product feed.

Build-time optional parameter: `--dart-define=STORE_LOOKUP_URL=https://your-service.example/stores`. Do not embed Google Places or retailer API secrets in the mobile app.

Request: `GET /stores?lat=45&lon=-75&radius=30000&ingredient=heavy%20cream`

Response (illustrative sample schema; no sample prices are verified):

```json
{
  "stores": [{
    "id": "store-123",
    "name": "Example Store",
    "latitude": 45,
    "longitude": -75,
    "address": "Example Road",
    "website": "https://example.com",
    "products": [{
      "name": "Whipping Cream",
      "size": "473 mL",
      "price": "4.29",
      "currency": "CAD",
      "availability": "in_stock",
      "productUrl": "https://example.com/products/cream",
      "updatedAt": "2026-11-13T20:00:00Z"
    }]
  }]
}
```

All product attributes are optional; absent fields are not fabricated. Recognized availability: `in_stock`, `out_of_stock`, `limited`. The worker is not included here and no live retailer catalogue is configured. Avoid unauthorized scraping. Protect user GPS coordinates and validate worker inputs, expiry and retailer data provenance before production deployment.
