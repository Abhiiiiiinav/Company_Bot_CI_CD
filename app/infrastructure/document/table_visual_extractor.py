"""Specialized extractor for visual tables producing Dual-Payload contracts.

Handles:
- Extracting both semantic summaries and structured 2D Markdown table grids from visual table assets.
- Robust markdown table grid sanitization and column alignment.
- Fallback recovery to standard semantic descriptions if table extraction fails.
"""

from __future__ import annotations

import logging
import re
from typing import Any

from app.domain.ports.visual_contract import VisualOutputContract
from app.infrastructure.document.vlm_engine import VisualUnderstandingEngine

logger = logging.getLogger("knowlayer.ingestion.visual.table")


class TableVisualExtractor:
    """Extracts structured 2D Markdown tables alongside semantic summaries from table images."""

    def __init__(self, vlm_engine: VisualUnderstandingEngine):
        self._vlm_engine = vlm_engine

    def extract(
        self,
        image_bytes: bytes,
        ocr_context: str = "",
        picture_ref: str = "",
    ) -> VisualOutputContract:
        """Extract a Dual-Payload contract for a visual table asset."""
        try:
            contract = self._vlm_engine.describe_table(
                image_bytes=image_bytes,
                ocr_context=ocr_context,
                picture_ref=picture_ref,
            )
            if contract and contract.table_markdown:
                contract.table_markdown = self.sanitize_markdown_table(contract.table_markdown)
            return contract
        except Exception as exc:
            logger.warning(
                "Table visual extraction failed for ref=%s: %s; falling back to standard visual description",
                picture_ref,
                exc,
            )
            return self._vlm_engine.describe(
                image_bytes=image_bytes,
                ocr_context=ocr_context,
                picture_ref=picture_ref,
            )

    @staticmethod
    def sanitize_markdown_table(table_text: str) -> str:
        """Clean and normalize raw Markdown table output from VLM.

        - Strips markdown code fences (```markdown / ```).
        - Filters out non-table conversational lines outside the grid.
        - Ensures valid row pipe delimiters.
        """
        if not table_text or not table_text.strip():
            return ""

        # Remove surrounding markdown fences
        cleaned = re.sub(r"^```(?:markdown)?\s*", "", table_text.strip())
        cleaned = re.sub(r"\s*```$", "", cleaned).strip()

        lines = cleaned.splitlines()
        table_lines = [
            line.strip()
            for line in lines
            if line.strip().startswith("|") and line.strip().endswith("|")
        ]

        if len(table_lines) >= 2:
            return "\n".join(table_lines)

        return cleaned
