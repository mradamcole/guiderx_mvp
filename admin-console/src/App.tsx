import { useCallback, useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";

type DbStatus = {
  status: "ok";
  databaseConnected: boolean;
  latencyMs: number;
  counts: {
    papers: number;
    studies: number;
    authors: number;
    outcomes: number;
  };
};

type PaperAuthor = {
  name: string;
  orcid: string | null;
  authorOrder: number | null;
  isCorresponding: boolean;
};

type PaperListItem = {
  paperId: string;
  title: string;
  doi: string | null;
  url: string | null;
  retrievalDate: string | null;
  isPeerReviewed: boolean | null;
  altmetricScore: number | null;
  journalName: string | null;
  publisherName: string | null;
  studyCount: number;
  authors: PaperAuthor[];
};

type ApiData<T> = { data: T };

type ExtractedDraft = {
  paper: {
    title?: string;
    doi?: string;
    url?: string;
    journalName?: string;
    publisherName?: string;
    isPeerReviewed?: boolean;
    altmetricScore?: number;
  };
  authors: Array<{
    name: string;
    authorOrder?: number;
  }>;
  ingestion: {
    concept?: {
      system?: FormState["conceptSystem"];
      code?: string;
      displayText?: string;
    };
    study?: {
      name?: string;
      studyTypeName?: string;
      sampleSize?: number;
      sponsor?: string;
    };
    arm?: {
      armType?: FormState["armType"];
      size?: number;
      productName?: string;
    };
    outcome?: {
      effectSize?: number;
      effectType?: FormState["effectType"];
      pValue?: number;
      timepoint?: string;
      summary?: string;
    };
  };
  confidence?: number;
  notes?: string[];
};

type FormState = {
  title: string;
  doi: string;
  url: string;
  journalName: string;
  publisherName: string;
  isPeerReviewed: boolean;
  altmetricScore: string;
  authorsCsv: string;
  conceptSystem: "ICD11" | "SNOMED-CT" | "RxNorm" | "Custom";
  conceptCode: string;
  conceptDisplayText: string;
  studyName: string;
  studyTypeName: string;
  sampleSize: string;
  sponsor: string;
  armType: "intervention" | "placebo" | "active_comparator";
  armSize: string;
  productName: string;
  effectSize: string;
  effectType: "RR" | "OR" | "SMD" | "Mean Difference" | "";
  pValue: string;
  timepoint: string;
  summary: string;
};

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000";

const initialFormState: FormState = {
  title: "",
  doi: "",
  url: "",
  journalName: "",
  publisherName: "",
  isPeerReviewed: true,
  altmetricScore: "",
  authorsCsv: "",
  conceptSystem: "Custom",
  conceptCode: "",
  conceptDisplayText: "",
  studyName: "",
  studyTypeName: "",
  sampleSize: "",
  sponsor: "",
  armType: "intervention",
  armSize: "",
  productName: "",
  effectSize: "",
  effectType: "",
  pValue: "",
  timepoint: "",
  summary: ""
};

function App() {
  const [dbStatus, setDbStatus] = useState<DbStatus | null>(null);
  const [papers, setPapers] = useState<PaperListItem[]>([]);
  const [statusLoading, setStatusLoading] = useState(false);
  const [papersLoading, setPapersLoading] = useState(false);
  const [formSubmitting, setFormSubmitting] = useState(false);
  const [extracting, setExtracting] = useState(false);
  const [isDragOver, setIsDragOver] = useState(false);
  const [statusError, setStatusError] = useState("");
  const [papersError, setPapersError] = useState("");
  const [formError, setFormError] = useState("");
  const [formSuccess, setFormSuccess] = useState("");
  const [extractError, setExtractError] = useState("");
  const [extractInfo, setExtractInfo] = useState("");
  const [formState, setFormState] = useState<FormState>(initialFormState);

  const hasPapers = papers.length > 0;

  const loadDbStatus = useCallback(async () => {
    setStatusLoading(true);
    setStatusError("");
    try {
      const response = await fetch(`${API_BASE_URL}/api/admin/db-status`);
      if (!response.ok) {
        throw new Error(`Status request failed (${response.status})`);
      }
      const payload = (await response.json()) as ApiData<DbStatus>;
      setDbStatus(payload.data);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Could not load database status.";
      setStatusError(message);
    } finally {
      setStatusLoading(false);
    }
  }, []);

  const loadPapers = useCallback(async () => {
    setPapersLoading(true);
    setPapersError("");
    try {
      const response = await fetch(`${API_BASE_URL}/api/admin/papers?limit=50&offset=0`);
      if (!response.ok) {
        throw new Error(`Paper list request failed (${response.status})`);
      }
      const payload = (await response.json()) as ApiData<PaperListItem[]>;
      setPapers(payload.data);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Could not load papers.";
      setPapersError(message);
    } finally {
      setPapersLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadDbStatus();
    void loadPapers();
  }, [loadDbStatus, loadPapers]);

  const parsedAuthors = useMemo(() => {
    return formState.authorsCsv
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean)
      .map((name, index) => ({
        name,
        authorOrder: index + 1
      }));
  }, [formState.authorsCsv]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setFormSubmitting(true);
    setFormError("");
    setFormSuccess("");

    try {
      const body = {
        paper: {
          title: formState.title,
          doi: formState.doi || undefined,
          url: formState.url || undefined,
          journalName: formState.journalName || undefined,
          publisherName: formState.publisherName || undefined,
          isPeerReviewed: formState.isPeerReviewed,
          altmetricScore: formState.altmetricScore ? Number(formState.altmetricScore) : undefined
        },
        authors: parsedAuthors,
        ingestions: [
          {
            concept: {
              system: formState.conceptSystem,
              code: formState.conceptCode,
              displayText: formState.conceptDisplayText
            },
            study: {
              name: formState.studyName,
              studyTypeName: formState.studyTypeName || undefined,
              sampleSize: formState.sampleSize ? Number(formState.sampleSize) : undefined,
              sponsor: formState.sponsor || undefined
            },
            arm: {
              armType: formState.armType,
              size: formState.armSize ? Number(formState.armSize) : undefined,
              productName: formState.productName || undefined
            },
            outcome: {
              effectSize: formState.effectSize ? Number(formState.effectSize) : undefined,
              effectType: formState.effectType || undefined,
              pValue: formState.pValue ? Number(formState.pValue) : undefined,
              timepoint: formState.timepoint || undefined,
              summary: formState.summary || undefined
            }
          }
        ]
      };

      const response = await fetch(`${API_BASE_URL}/api/admin/papers`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body)
      });

      if (!response.ok) {
        const errorPayload = (await response.json().catch(() => null)) as
          | { message?: string; error?: string }
          | null;
        throw new Error(errorPayload?.message ?? `Create paper failed (${response.status})`);
      }

      setFormSuccess("Paper created and linked to ingestion records.");
      setFormState(initialFormState);
      await Promise.all([loadDbStatus(), loadPapers()]);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Could not create paper.";
      setFormError(message);
    } finally {
      setFormSubmitting(false);
    }
  }

  function updateField<K extends keyof FormState>(key: K, value: FormState[K]) {
    setFormState((previous) => ({ ...previous, [key]: value }));
  }

  function applyExtractedDraft(draft: ExtractedDraft) {
    setFormState((previous) => ({
      ...previous,
      title: draft.paper.title ?? previous.title,
      doi: draft.paper.doi ?? previous.doi,
      url: draft.paper.url ?? previous.url,
      journalName: draft.paper.journalName ?? previous.journalName,
      publisherName: draft.paper.publisherName ?? previous.publisherName,
      isPeerReviewed: draft.paper.isPeerReviewed ?? previous.isPeerReviewed,
      altmetricScore:
        draft.paper.altmetricScore !== undefined
          ? String(draft.paper.altmetricScore)
          : previous.altmetricScore,
      authorsCsv:
        draft.authors.length > 0
          ? draft.authors
              .sort((a, b) => (a.authorOrder ?? Number.MAX_SAFE_INTEGER) - (b.authorOrder ?? Number.MAX_SAFE_INTEGER))
              .map((author) => author.name)
              .join("\n")
          : previous.authorsCsv,
      conceptSystem: draft.ingestion.concept?.system ?? previous.conceptSystem,
      conceptCode: draft.ingestion.concept?.code ?? previous.conceptCode,
      conceptDisplayText: draft.ingestion.concept?.displayText ?? previous.conceptDisplayText,
      studyName: draft.ingestion.study?.name ?? previous.studyName,
      studyTypeName: draft.ingestion.study?.studyTypeName ?? previous.studyTypeName,
      sampleSize:
        draft.ingestion.study?.sampleSize !== undefined
          ? String(draft.ingestion.study.sampleSize)
          : previous.sampleSize,
      sponsor: draft.ingestion.study?.sponsor ?? previous.sponsor,
      armType: draft.ingestion.arm?.armType ?? previous.armType,
      armSize: draft.ingestion.arm?.size !== undefined ? String(draft.ingestion.arm.size) : previous.armSize,
      productName: draft.ingestion.arm?.productName ?? previous.productName,
      effectSize:
        draft.ingestion.outcome?.effectSize !== undefined
          ? String(draft.ingestion.outcome.effectSize)
          : previous.effectSize,
      effectType: draft.ingestion.outcome?.effectType ?? previous.effectType,
      pValue:
        draft.ingestion.outcome?.pValue !== undefined
          ? String(draft.ingestion.outcome.pValue)
          : previous.pValue,
      timepoint: draft.ingestion.outcome?.timepoint ?? previous.timepoint,
      summary: draft.ingestion.outcome?.summary ?? previous.summary
    }));

    const notes = draft.notes?.filter(Boolean) ?? [];
    const confidence =
      typeof draft.confidence === "number"
        ? `Extraction confidence: ${(draft.confidence * 100).toFixed(0)}%`
        : "";
    setExtractInfo([confidence, ...notes].filter(Boolean).join(" | "));
  }

  async function uploadPaperForExtraction(file: File) {
    setExtractError("");
    setExtractInfo("");
    setFormError("");
    setFormSuccess("");
    setExtracting(true);
    try {
      const formData = new FormData();
      formData.append("paper", file);

      const response = await fetch(`${API_BASE_URL}/api/admin/papers/extract`, {
        method: "POST",
        body: formData
      });

      if (!response.ok) {
        const errorPayload = (await response.json().catch(() => null)) as
          | { message?: string; error?: string }
          | null;
        throw new Error(errorPayload?.message ?? `Extraction failed (${response.status})`);
      }

      const payload = (await response.json()) as ApiData<ExtractedDraft>;
      applyExtractedDraft(payload.data);
      setExtractInfo((previous) =>
        previous ? previous : "Extraction completed. Review fields before creating the paper."
      );
    } catch (error) {
      const message = error instanceof Error ? error.message : "Failed to extract fields from file.";
      setExtractError(message);
    } finally {
      setExtracting(false);
      setIsDragOver(false);
    }
  }

  return (
    <main className="container">
      <header className="page-header">
        <h1>GuideRx Admin Console</h1>
        <p>Unauthenticated v1 console for DB health and publication ingestion workflows.</p>
      </header>

      <section className="panel">
        <div className="panel-title">
          <h2>Database Status</h2>
          <button type="button" onClick={() => void loadDbStatus()} disabled={statusLoading}>
            {statusLoading ? "Refreshing..." : "Refresh"}
          </button>
        </div>
        {statusError ? <p className="error">{statusError}</p> : null}
        {dbStatus ? (
          <div className="status-grid">
            <div><strong>Status:</strong> {dbStatus.status}</div>
            <div><strong>Connected:</strong> {String(dbStatus.databaseConnected)}</div>
            <div><strong>Latency:</strong> {dbStatus.latencyMs.toFixed(2)} ms</div>
            <div><strong>Papers:</strong> {dbStatus.counts.papers}</div>
            <div><strong>Studies:</strong> {dbStatus.counts.studies}</div>
            <div><strong>Authors:</strong> {dbStatus.counts.authors}</div>
            <div><strong>Outcomes:</strong> {dbStatus.counts.outcomes}</div>
          </div>
        ) : (
          <p>{statusLoading ? "Loading status..." : "No status loaded yet."}</p>
        )}
      </section>

      <section className="panel">
        <div className="panel-title">
          <h2>Research Papers</h2>
          <button type="button" onClick={() => void loadPapers()} disabled={papersLoading}>
            {papersLoading ? "Refreshing..." : "Refresh"}
          </button>
        </div>
        {papersError ? <p className="error">{papersError}</p> : null}
        {!hasPapers && !papersLoading ? <p>No papers found.</p> : null}
        {hasPapers ? (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Title</th>
                  <th>DOI</th>
                  <th>Journal</th>
                  <th>Publisher</th>
                  <th>Authors</th>
                  <th>Studies</th>
                </tr>
              </thead>
              <tbody>
                {papers.map((paper) => (
                  <tr key={paper.paperId}>
                    <td>{paper.title}</td>
                    <td>{paper.doi ?? "-"}</td>
                    <td>{paper.journalName ?? "-"}</td>
                    <td>{paper.publisherName ?? "-"}</td>
                    <td>{paper.authors.map((author) => author.name).join(", ") || "-"}</td>
                    <td>{paper.studyCount}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}
      </section>

      <section className="panel">
        <h2>Add Research Paper</h2>
        <div
          className={`upload-dropzone ${isDragOver ? "drag-over" : ""}`}
          onDragOver={(event) => {
            event.preventDefault();
            setIsDragOver(true);
          }}
          onDragLeave={() => setIsDragOver(false)}
          onDrop={(event) => {
            event.preventDefault();
            const file = event.dataTransfer.files?.[0];
            if (file) {
              void uploadPaperForExtraction(file);
            }
          }}
        >
          <p>
            Upload paper to auto-fill fields (PDF or text): drag and drop here, or use file picker.
          </p>
          <label className="upload-button">
            <input
              type="file"
              accept=".pdf,.txt,.md,.json,.csv,application/pdf,text/plain"
              onChange={(event) => {
                const file = event.target.files?.[0];
                if (file) {
                  void uploadPaperForExtraction(file);
                }
                event.currentTarget.value = "";
              }}
              disabled={extracting}
            />
            {extracting ? "Extracting..." : "Select File"}
          </label>
          {extractError ? <p className="error">{extractError}</p> : null}
          {extractInfo ? <p className="success">{extractInfo}</p> : null}
        </div>

        <form onSubmit={(event) => void handleSubmit(event)} className="form-grid">
          <label>
            Paper Title*
            <input
              value={formState.title}
              onChange={(event) => updateField("title", event.target.value)}
              required
            />
          </label>
          <label>
            DOI
            <input value={formState.doi} onChange={(event) => updateField("doi", event.target.value)} />
          </label>
          <label>
            URL
            <input value={formState.url} onChange={(event) => updateField("url", event.target.value)} />
          </label>
          <label>
            Journal
            <input
              value={formState.journalName}
              onChange={(event) => updateField("journalName", event.target.value)}
            />
          </label>
          <label>
            Publisher
            <input
              value={formState.publisherName}
              onChange={(event) => updateField("publisherName", event.target.value)}
            />
          </label>
          <label>
            Altmetric Score
            <input
              type="number"
              min={0}
              value={formState.altmetricScore}
              onChange={(event) => updateField("altmetricScore", event.target.value)}
            />
          </label>
          <label className="checkbox">
            <input
              type="checkbox"
              checked={formState.isPeerReviewed}
              onChange={(event) => updateField("isPeerReviewed", event.target.checked)}
            />
            Peer reviewed
          </label>
          <label className="full-width">
            Authors (one per line)
            <textarea
              value={formState.authorsCsv}
              onChange={(event) => updateField("authorsCsv", event.target.value)}
              rows={4}
              placeholder={"Author One\nAuthor Two"}
            />
          </label>

          <h3 className="full-width">Initial Ingestion Block</h3>
          <label>
            Concept System*
            <select
              value={formState.conceptSystem}
              onChange={(event) => updateField("conceptSystem", event.target.value as FormState["conceptSystem"])}
            >
              <option value="Custom">Custom</option>
              <option value="ICD11">ICD11</option>
              <option value="SNOMED-CT">SNOMED-CT</option>
              <option value="RxNorm">RxNorm</option>
            </select>
          </label>
          <label>
            Concept Code*
            <input
              value={formState.conceptCode}
              onChange={(event) => updateField("conceptCode", event.target.value)}
              required
            />
          </label>
          <label>
            Concept Display Text*
            <input
              value={formState.conceptDisplayText}
              onChange={(event) => updateField("conceptDisplayText", event.target.value)}
              required
            />
          </label>
          <label>
            Study Name*
            <input
              value={formState.studyName}
              onChange={(event) => updateField("studyName", event.target.value)}
              required
            />
          </label>
          <label>
            Study Type
            <input
              value={formState.studyTypeName}
              onChange={(event) => updateField("studyTypeName", event.target.value)}
            />
          </label>
          <label>
            Sample Size
            <input
              type="number"
              min={0}
              value={formState.sampleSize}
              onChange={(event) => updateField("sampleSize", event.target.value)}
            />
          </label>
          <label>
            Sponsor
            <input value={formState.sponsor} onChange={(event) => updateField("sponsor", event.target.value)} />
          </label>
          <label>
            Arm Type*
            <select
              value={formState.armType}
              onChange={(event) => updateField("armType", event.target.value as FormState["armType"])}
            >
              <option value="intervention">intervention</option>
              <option value="placebo">placebo</option>
              <option value="active_comparator">active_comparator</option>
            </select>
          </label>
          <label>
            Arm Size
            <input
              type="number"
              min={0}
              value={formState.armSize}
              onChange={(event) => updateField("armSize", event.target.value)}
            />
          </label>
          <label>
            Product Name
            <input
              value={formState.productName}
              onChange={(event) => updateField("productName", event.target.value)}
            />
          </label>
          <label>
            Effect Size
            <input
              type="number"
              step="any"
              value={formState.effectSize}
              onChange={(event) => updateField("effectSize", event.target.value)}
            />
          </label>
          <label>
            Effect Type
            <select
              value={formState.effectType}
              onChange={(event) => updateField("effectType", event.target.value as FormState["effectType"])}
            >
              <option value="">-</option>
              <option value="RR">RR</option>
              <option value="OR">OR</option>
              <option value="SMD">SMD</option>
              <option value="Mean Difference">Mean Difference</option>
            </select>
          </label>
          <label>
            P Value
            <input
              type="number"
              min={0}
              max={1}
              step="any"
              value={formState.pValue}
              onChange={(event) => updateField("pValue", event.target.value)}
            />
          </label>
          <label>
            Timepoint
            <input
              value={formState.timepoint}
              onChange={(event) => updateField("timepoint", event.target.value)}
            />
          </label>
          <label className="full-width">
            Outcome Summary
            <textarea
              value={formState.summary}
              onChange={(event) => updateField("summary", event.target.value)}
              rows={3}
            />
          </label>

          {formError ? <p className="error full-width">{formError}</p> : null}
          {formSuccess ? <p className="success full-width">{formSuccess}</p> : null}
          <div className="full-width">
            <button type="submit" disabled={formSubmitting}>
              {formSubmitting ? "Submitting..." : "Create Paper + Populate Tables"}
            </button>
          </div>
        </form>
      </section>
    </main>
  );
}

export default App;
