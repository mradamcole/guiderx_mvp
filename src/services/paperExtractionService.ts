import { PDFParse } from "pdf-parse";
import { llmRouter } from "../llm";
import {
  AdminPaperExtractedDraft,
  adminPaperExtractedDraftSchema
} from "../validation/schemas";

const MAX_LLM_INPUT_CHARS = 20000;

type UploadLike = {
  originalname: string;
  mimetype: string;
  buffer: Buffer;
};

export async function extractDraftFromUpload(upload: UploadLike): Promise<AdminPaperExtractedDraft> {
  const extractedText = await extractTextFromUpload(upload);
  if (!extractedText.trim()) {
    throw new Error("Uploaded file did not contain extractable text.");
  }

  const promptText = extractedText.slice(0, MAX_LLM_INPUT_CHARS);
  const llmResult = await llmRouter.generate({
    route: "summarization",
    temperature: 0,
    maxTokens: 1200,
    messages: [
      {
        role: "system",
        content:
          "You extract structured medical publication metadata and one initial evidence ingestion draft. Return only JSON."
      },
      {
        role: "user",
        content: [
          "Extract the best-effort fields from this paper text.",
          "Return strictly valid JSON with this shape:",
          "{",
          '  "paper": {',
          '    "title": "string",',
          '    "doi": "string?",',
          '    "url": "string?",',
          '    "journalName": "string?",',
          '    "publisherName": "string?",',
          '    "isPeerReviewed": "boolean?",',
          '    "altmetricScore": "number?"',
          "  },",
          '  "authors": [{"name":"string","orcid":"string?","authorOrder":"number?","isCorresponding":"boolean?"}],',
          '  "ingestion": {',
          '    "concept": {"system":"ICD11|SNOMED-CT|RxNorm|Custom?","code":"string?","displayText":"string?"},',
          '    "study": {"name":"string?","studyTypeName":"string?","sampleSize":"number?","sponsor":"string?"},',
          '    "arm": {"armType":"intervention|placebo|active_comparator?","size":"number?","productName":"string?"},',
          '    "outcome": {"effectSize":"number?","effectType":"RR|OR|SMD|Mean Difference?","pValue":"number?","timepoint":"string?","summary":"string?"}',
          "  },",
          '  "confidence": "number 0..1?",',
          '  "notes": ["string"]',
          "}",
          "Rules:",
          "- Do not invent facts; leave unknown fields undefined or empty.",
          "- For concept.system use Custom unless a standard code system is explicit.",
          "- Pick one best initial ingestion draft from the most salient efficacy finding.",
          "- Respond with JSON only, no markdown fences.",
          "",
          `Filename: ${upload.originalname}`,
          "Paper text:",
          promptText
        ].join("\n")
      }
    ]
  });

  const parsedJson = parseJsonFromModel(llmResult.text);
  const parsed = adminPaperExtractedDraftSchema.parse(parsedJson);

  // Ensure safe defaults for required create-form fields that may be absent.
  if (!parsed.ingestion.concept.system) {
    parsed.ingestion.concept.system = "Custom";
  }
  if (!parsed.ingestion.arm.armType) {
    parsed.ingestion.arm.armType = "intervention";
  }

  return parsed;
}

async function extractTextFromUpload(upload: UploadLike): Promise<string> {
  const mime = upload.mimetype.toLowerCase();
  const name = upload.originalname.toLowerCase();

  if (mime === "application/pdf" || name.endsWith(".pdf")) {
    const parser = new PDFParse({
      data: new Uint8Array(upload.buffer)
    });
    try {
      const textResult = await parser.getText();
      return textResult.text ?? "";
    } finally {
      await parser.destroy();
    }
  }

  if (
    mime.startsWith("text/") ||
    name.endsWith(".txt") ||
    name.endsWith(".md") ||
    name.endsWith(".csv") ||
    name.endsWith(".json")
  ) {
    return upload.buffer.toString("utf-8");
  }

  throw new Error("Unsupported file type. Upload a PDF or plain text file.");
}

function parseJsonFromModel(text: string): unknown {
  const trimmed = text.trim();
  if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
    return JSON.parse(trimmed);
  }

  const fenced = trimmed.match(/```json\s*([\s\S]*?)```/i) ?? trimmed.match(/```\s*([\s\S]*?)```/i);
  if (fenced?.[1]) {
    return JSON.parse(fenced[1].trim());
  }

  const firstBrace = trimmed.indexOf("{");
  const lastBrace = trimmed.lastIndexOf("}");
  if (firstBrace >= 0 && lastBrace > firstBrace) {
    return JSON.parse(trimmed.slice(firstBrace, lastBrace + 1));
  }

  throw new Error("Could not parse structured JSON from LLM extraction response.");
}
