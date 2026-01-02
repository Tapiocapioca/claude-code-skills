"""
VTT Cleaner - Remove duplicates from YouTube auto-generated subtitles.

YouTube VTT files often have repeated text with slight timing variations.
This module cleans them to produce readable transcripts.
"""

import re
from typing import List


def clean_vtt_content(vtt_content: str) -> str:
    """
    Clean VTT content by removing duplicates and timestamps.

    Args:
        vtt_content: Raw VTT file content

    Returns:
        Cleaned transcript text
    """
    lines = vtt_content.split('\n')
    text_lines: List[str] = []
    seen_text: set = set()

    for line in lines:
        # Skip header, empty lines, and timestamp lines
        if line.startswith('WEBVTT') or line.startswith('Kind:') or line.startswith('Language:'):
            continue
        if re.match(r'^\d{2}:\d{2}:\d{2}\.\d{3} --> \d{2}:\d{2}:\d{2}\.\d{3}', line):
            continue
        if not line.strip():
            continue
        if re.match(r'^\d+$', line.strip()):  # Line numbers
            continue

        # Remove HTML tags like <c> </c>
        clean_line = re.sub(r'<[^>]+>', '', line)
        clean_line = clean_line.strip()

        if clean_line and clean_line not in seen_text:
            # Check if it's not just a partial duplicate
            is_substring = False
            for seen in list(seen_text)[-20:]:  # Check against last 20 lines
                if clean_line in seen or seen in clean_line:
                    is_substring = True
                    # If the new line is longer, replace
                    if len(clean_line) > len(seen):
                        seen_text.discard(seen)
                        text_lines = [l for l in text_lines if l != seen]
                        is_substring = False
                    break

            if not is_substring:
                seen_text.add(clean_line)
                text_lines.append(clean_line)

    return '\n'.join(text_lines)
