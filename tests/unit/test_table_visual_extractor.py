"""Unit tests for TableVisualExtractor and Dual-Payload visual table contracts."""

from __future__ import annotations

from unittest.mock import MagicMock

import pytest

from app.domain.ports.visual_contract import VisualOutputContract
from app.infrastructure.document.table_visual_extractor import TableVisualExtractor


def test_sanitize_markdown_table_strips_fences_and_preamble():
    raw_vlm_output = """
Here is the extracted table from the image:
```markdown
| Pay Rate | 30 hrs | 40 hrs |
| :--- | :--- | :--- |
| $8.15 | $91.00 | $121.11 |
| $11.05 | $123.39 | $164.52 |
```
Note: Overtime is calculated at 43 hours.
"""
    sanitized = TableVisualExtractor.sanitize_markdown_table(raw_vlm_output)
    lines = sanitized.splitlines()
    assert len(lines) == 4
    assert lines[0] == "| Pay Rate | 30 hrs | 40 hrs |"
    assert lines[1] == "| :--- | :--- | :--- |"
    assert lines[2] == "| $8.15 | $91.00 | $121.11 |"
    assert lines[3] == "| $11.05 | $123.39 | $164.52 |"


def test_sanitize_markdown_table_empty_handling():
    assert TableVisualExtractor.sanitize_markdown_table("") == ""
    assert TableVisualExtractor.sanitize_markdown_table("   ") == ""
    assert TableVisualExtractor.sanitize_markdown_table("Just text with no table") == "Just text with no table"


def test_table_visual_extractor_successful_dual_contract():
    mock_vlm = MagicMock()
    mock_contract = VisualOutputContract(
        visual_type="table",
        summary="Monthly health insurance premium deductions capped at 9.49% of W2.",
        table_markdown="""| Pay Rate | Monthly Deduction |
| :--- | :--- |
| $10.00 | $120.00 |""",
        source_reference="#/pictures/0",
    )
    mock_vlm.describe_table.return_value = mock_contract

    extractor = TableVisualExtractor(mock_vlm)
    res = extractor.extract(b"dummy_bytes", picture_ref="#/pictures/0")

    assert res.visual_type == "table"
    assert "9.49%" in res.summary
    assert res.table_markdown is not None
    assert "$10.00" in res.table_markdown
    mock_vlm.describe_table.assert_called_once_with(
        image_bytes=b"dummy_bytes",
        ocr_context="",
        picture_ref="#/pictures/0",
    )


def test_table_visual_extractor_fallback_on_error():
    mock_vlm = MagicMock()
    mock_vlm.describe_table.side_effect = RuntimeError("Table inference timeout")
    mock_fallback_contract = VisualOutputContract(
        visual_type="table",
        summary="Fallback summary of table visual.",
        source_reference="#/pictures/0",
    )
    mock_vlm.describe.return_value = mock_fallback_contract

    extractor = TableVisualExtractor(mock_vlm)
    res = extractor.extract(b"dummy_bytes", picture_ref="#/pictures/0")

    assert res.summary == "Fallback summary of table visual."
    mock_vlm.describe.assert_called_once_with(
        image_bytes=b"dummy_bytes",
        ocr_context="",
        picture_ref="#/pictures/0",
    )


def test_visual_output_contract_dual_payload_rendering():
    # Case 1: Standard diagram (no table_markdown)
    diagram_contract = VisualOutputContract(
        visual_type="architecture_diagram",
        summary="Architecture showing Client, API Gateway, and Database.",
        entities=["Client", "API Gateway", "Database"],
        relationships=["Client -> API Gateway", "API Gateway -> Database"],
    )
    text_diagram = diagram_contract.to_search_text()
    assert "[Structured Table Data]" not in text_diagram
    assert "Summary: Architecture showing Client" in text_diagram
    assert diagram_contract.to_metadata()["has_table_grid"] is False

    # Case 2: Visual Table with Dual-Payload
    table_contract = VisualOutputContract(
        visual_type="table",
        summary="Insurance deduction schedule capped at 9.49% of W2 wages.",
        table_markdown="| Pay Rate | Deduction |\n| :--- | :--- |\n| $11.05 | $164.52 |",
        source_reference="#/pictures/0",
    )
    text_table = table_contract.to_search_text()
    assert "Summary: Insurance deduction schedule" in text_table
    assert "[Structured Table Data]" in text_table
    assert "| $11.05 | $164.52 |" in text_table
    assert table_contract.to_metadata()["has_table_grid"] is True
