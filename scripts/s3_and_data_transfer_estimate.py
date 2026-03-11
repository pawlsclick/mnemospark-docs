#!/usr/bin/env python3
import json
import subprocess
import sys
from decimal import Decimal


PRICING_REGION = "us-east-1"  # Price List API endpoint region
S3_LOCATION = "US East (N. Virginia)"  # human-readable AWS pricing location


def run_aws_pricing(filters):
    cmd = [
        "aws", "pricing", "get-products",
        "--region", PRICING_REGION,
        "--service-code", "AmazonS3",
        "--max-results", "100",
    ]

    for f in filters:
        cmd.extend(["--filters", f])

    out = subprocess.check_output(cmd, text=True)
    data = json.loads(out)

    if not data.get("PriceList"):
        raise RuntimeError("No pricing results returned for filters")

    return [json.loads(item) for item in data["PriceList"]]


def extract_usd_prices(product_docs):
    """
    Return a list of (description, begin_range, end_range, usd_price) tuples
    from OnDemand terms.
    """
    prices = []

    for doc in product_docs:
        terms = doc.get("terms", {}).get("OnDemand", {})
        for _, term in terms.items():
            dims = term.get("priceDimensions", {})
            for _, dim in dims.items():
                price_str = dim.get("pricePerUnit", {}).get("USD")
                if price_str is None:
                    continue
                prices.append({
                    "description": dim.get("description", ""),
                    "begin_range": dim.get("beginRange", "0"),
                    "end_range": dim.get("endRange", "Inf"),
                    "price": Decimal(price_str),
                    "unit": dim.get("unit", "")
                })
    return prices


def choose_tier(prices, usage_amount):
    """
    Pick the tier that matches usage_amount based on begin/end range.
    """
    usage = Decimal(str(usage_amount))

    for p in prices:
        begin = Decimal(p["begin_range"])
        end = Decimal("Infinity") if p["end_range"] == "Inf" else Decimal(p["end_range"])
        if usage >= begin and usage < end:
            return p

    raise RuntimeError(f"No matching price tier found for usage={usage_amount}")


def get_s3_standard_storage_price_per_gb_month():
    filters = [
        "Type=TERM_MATCH,Field=productFamily,Value=Storage",
        f'Type=TERM_MATCH,Field=location,Value={S3_LOCATION}',
        "Type=TERM_MATCH,Field=volumeType,Value=Standard",
    ]
    docs = run_aws_pricing(filters)
    prices = extract_usd_prices(docs)

    # Prefer GB-Mo style storage pricing
    gb_prices = [p for p in prices if "GB" in p["unit"] or "GB" in p["description"]]
    if not gb_prices:
        raise RuntimeError("Could not find S3 Standard storage GB pricing")
    return choose_tier(gb_prices, 1)


def get_s3_data_transfer_out_price_per_gb():
    # Data Transfer products use fromLocation (not location) and transferType
    # value "AWS Outbound" (not "Out-Bytes"). See AWS Price List API
    # get-attribute-values for AmazonS3 transferType and fromLocation.
    filters = [
        "Type=TERM_MATCH,Field=productFamily,Value=Data Transfer",
        f'Type=TERM_MATCH,Field=fromLocation,Value={S3_LOCATION}',
        "Type=TERM_MATCH,Field=transferType,Value=AWS Outbound",
    ]
    docs = run_aws_pricing(filters)
    prices = extract_usd_prices(docs)

    # Prefer internet outbound GB transfer pricing
    gb_prices = [p for p in prices if "GB" in p["unit"] or "GB" in p["description"]]
    if not gb_prices:
        raise RuntimeError("Could not find S3 data transfer out GB pricing")
    return choose_tier(gb_prices, 1)


def main():
    storage_gb = Decimal(sys.argv[1]) if len(sys.argv) > 1 else Decimal("1")
    transfer_gb = Decimal(sys.argv[2]) if len(sys.argv) > 2 else Decimal("1")

    storage_tier = get_s3_standard_storage_price_per_gb_month()
    transfer_tier = get_s3_data_transfer_out_price_per_gb()

    storage_cost = storage_tier["price"] * storage_gb
    transfer_cost = transfer_tier["price"] * transfer_gb
    total = storage_cost + transfer_cost

    print("S3 estimator")
    print(f"Region: {S3_LOCATION}")
    print()
    print("Storage:")
    print(f"  Tier: {storage_tier['description']}")
    print(f"  Unit price: ${storage_tier['price']} per {storage_tier['unit']}")
    print(f"  Usage: {storage_gb} GB-month")
    print(f"  Cost: ${storage_cost}")
    print()
    print("Data transfer out:")
    print(f"  Tier: {transfer_tier['description']}")
    print(f"  Unit price: ${transfer_tier['price']} per {transfer_tier['unit']}")
    print(f"  Usage: {transfer_gb} GB")
    print(f"  Cost: ${transfer_cost}")
    print()
    print(f"Total estimated cost: ${total}")


if __name__ == "__main__":
    main()