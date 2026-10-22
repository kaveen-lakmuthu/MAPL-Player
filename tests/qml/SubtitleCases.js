.pragma library

function rows() {
    return [
        {
            "tag": "VTT keeps full stops",
            "format": "vtt",
            "input": "WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello. World.",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "Hello. World."
                }
            ]
        },
        {
            "tag": "VTT accepts timestamps without hours",
            "format": "vtt",
            "input": "WEBVTT\n\n00:01.000 --> 00:02.000\nHello.",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "Hello."
                }
            ]
        },
        {
            "tag": "VTT preserves decimals, commas and URLs in text",
            "format": "vtt",
            "input": "WEBVTT\n\n00:01.250 --> 00:02.500\nVersion 1.25, https://example.com.",
            "expected": [
                {
                    "start": 1.25,
                    "end": 2.5,
                    "text": "Version 1.25, https://example.com."
                }
            ]
        },
        {
            "tag": "VTT parses hour fields",
            "format": "vtt",
            "input": "WEBVTT\n\n01:02:03.456 --> 01:02:05.789\nLong movie.",
            "expected": [
                {
                    "start": 3723.456,
                    "end": 3725.789,
                    "text": "Long movie."
                }
            ]
        },
        {
            "tag": "VTT accepts mixed timestamp forms",
            "format": "vtt",
            "input": "WEBVTT\n\n59:59.500 --> 01:00:00.000\nBoundary.",
            "expected": [
                {
                    "start": 3599.5,
                    "end": 3600,
                    "text": "Boundary."
                }
            ]
        },
        {
            "tag": "VTT ignores cue settings when parsing end time",
            "format": "vtt",
            "input": "WEBVTT\n\n00:01.250 --> 00:02.500 align:start line:90% position:50%\nHello.",
            "expected": [
                {
                    "start": 1.25,
                    "end": 2.5,
                    "text": "Hello."
                }
            ]
        },
        {
            "tag": "VTT accepts cue IDs",
            "format": "vtt",
            "input": "WEBVTT\n\nintro.1\n00:01.000 --> 00:02.000\nIntroduction.",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "Introduction."
                }
            ]
        },
        {
            "tag": "VTT accepts numeric cue IDs",
            "format": "vtt",
            "input": "WEBVTT\n\n1\n00:00:01.000 --> 00:00:02.000\nHello.",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "Hello."
                }
            ]
        },
        {
            "tag": "VTT keeps multiline text",
            "format": "vtt",
            "input": "WEBVTT\n\n00:01.000 --> 00:02.000\nFirst line.\nSecond line.",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "First line.\nSecond line."
                }
            ]
        },
        {
            "tag": "VTT normalizes CRLF line endings",
            "format": "vtt",
            "input": "WEBVTT\r\n\r\n00:01.000 --> 00:02.000\r\nHello.\r\n",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "Hello."
                }
            ]
        },
        {
            "tag": "VTT normalizes CR line endings",
            "format": "vtt",
            "input": "WEBVTT\r\r00:01.000 --> 00:02.000\rHello.",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "Hello."
                }
            ]
        },
        {
            "tag": "VTT accepts a UTF-8 BOM and header description",
            "format": "vtt",
            "input": "﻿WEBVTT - captions\n\n00:01.000 --> 00:02.000\nHello.",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "Hello."
                }
            ]
        },
        {
            "tag": "VTT accepts whitespace-only block separators",
            "format": "vtt",
            "input": "WEBVTT\n \t\n00:01.000 --> 00:02.000\nFirst.\n \n00:03.000 --> 00:04.000\nSecond.",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "First."
                },
                {
                    "start": 3,
                    "end": 4,
                    "text": "Second."
                }
            ]
        },
        {
            "tag": "VTT skips NOTE blocks",
            "format": "vtt",
            "input": "WEBVTT\n\nNOTE editor comment\nDo not display this.\n\n00:01.000 --> 00:02.000\nHello.",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "Hello."
                }
            ]
        },
        {
            "tag": "VTT skips STYLE and REGION blocks",
            "format": "vtt",
            "input": "WEBVTT\n\nSTYLE\n::cue { color: red; }\n\nREGION\nid:fred\nwidth:40%\n\n00:01.000 --> 00:02.000\nHello.",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "Hello."
                }
            ]
        },
        {
            "tag": "VTT preserves metadata words in cue text",
            "format": "vtt",
            "input": "WEBVTT\n\n00:01.000 --> 00:02.000\nNOTE: WEBVTT uses STYLE and REGION blocks.",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "NOTE: WEBVTT uses STYLE and REGION blocks."
                }
            ]
        },
        {
            "tag": "VTT does not treat NOTEBOOK cue IDs as comments",
            "format": "vtt",
            "input": "WEBVTT\n\nNOTEBOOK\n00:01.000 --> 00:02.000\nHello.",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "Hello."
                }
            ]
        },
        {
            "tag": "VTT preserves Unicode text",
            "format": "vtt",
            "input": "WEBVTT\n\n00:01.000 --> 00:02.000\nආයුබෝවන්. こんにちは。",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "ආයුබෝවන්. こんにちは。"
                }
            ]
        },
        {
            "tag": "VTT still strips inline markup",
            "format": "vtt",
            "input": "WEBVTT\n\n00:01.000 --> 00:02.000\n<b>Hello.</b> <i>World.</i>",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "Hello. World."
                }
            ]
        },
        {
            "tag": "VTT header without cues yields no subtitles",
            "format": "vtt",
            "input": "WEBVTT\n\nNOTE Nothing to show.",
            "expected": []
        },
        {
            "tag": "SRT still parses comma timestamps",
            "format": "srt",
            "input": "1\n00:00:01,250 --> 00:00:02,500\nHello. World.",
            "expected": [
                {
                    "start": 1.25,
                    "end": 2.5,
                    "text": "Hello. World."
                }
            ]
        },
        {
            "tag": "SRT still handles CRLF and multiple cues",
            "format": "srt",
            "input": "1\r\n00:00:01,000 --> 00:00:02,000\r\nFirst.\r\n\r\n2\r\n00:00:03,000 --> 00:00:04,000\r\nSecond.",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "First."
                },
                {
                    "start": 3,
                    "end": 4,
                    "text": "Second."
                }
            ]
        },
        {
            "tag": "SRT still strips formatting and ASS escapes",
            "format": "srt",
            "input": "1\n00:00:01,000 --> 00:00:02,000\n{\\an8}<b>Hello.</b>\\NWorld.",
            "expected": [
                {
                    "start": 1,
                    "end": 2,
                    "text": "Hello.\nWorld."
                }
            ]
        }
    ];
}
