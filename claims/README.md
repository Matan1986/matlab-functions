# Claims Layer

Scientific claims are stored as individual JSON files in this directory.

Storage pattern:

```text
claims/<claim_id>.json
```

Claim schema:

```json
{
  "claim_id": "",
  "statement": "",
  "status": "hypothesis | tentative | supported | established",
  "source_runs": [],
  "related_surveys": [],
  "notes": ""
}
```

Notes:

- `claim_id` should match the JSON filename stem.
- `source_runs` must contain run IDs only.
- Claims are maintained manually or through review; they are not auto-generated from reports.