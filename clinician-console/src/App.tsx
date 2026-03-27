import { useMemo, useState } from "react";

type FakeSsoProvider = "google" | "apple" | "microsoft";
type ProviderDetails = {
  label: string;
  icon: string;
  accentClass: string;
};

const providerDetails: Record<FakeSsoProvider, ProviderDetails> = {
  google: { label: "Google", icon: "G", accentClass: "google" },
  apple: { label: "Apple", icon: "A", accentClass: "apple" },
  microsoft: { label: "Microsoft", icon: "M", accentClass: "microsoft" }
};

function App() {
  const [selectedProvider, setSelectedProvider] = useState<FakeSsoProvider | null>(null);
  const [pendingProvider, setPendingProvider] = useState<FakeSsoProvider | null>(null);
  const authTimestamp = useMemo(
    () => new Intl.DateTimeFormat("en-US", { dateStyle: "medium", timeStyle: "short" }).format(new Date()),
    []
  );

  async function handleSsoSignIn(provider: FakeSsoProvider) {
    setPendingProvider(provider);
    await new Promise((resolve) => setTimeout(resolve, 750));
    setSelectedProvider(provider);
    setPendingProvider(null);
  }

  if (selectedProvider) {
    const provider = providerDetails[selectedProvider];
    return (
      <main className="container">
        <section className="panel success-panel">
          <p className="badge">Authenticated</p>
          <h1>GuideRx Clinician Console</h1>
          <p className="auth-subtitle">
            Signed in with {provider.label}. This is a simulated OAuth response for UI development only.
          </p>

          <div className="session-details">
            <div>
              <span>Provider</span>
              <strong>{provider.label}</strong>
            </div>
            <div>
              <span>Session Started</span>
              <strong>{authTimestamp}</strong>
            </div>
            <div>
              <span>Role</span>
              <strong>Clinician (Demo)</strong>
            </div>
          </div>

          <div className="action-row">
            <button type="button" onClick={() => setSelectedProvider(null)}>
              Sign out
            </button>
          </div>
        </section>
      </main>
    );
  }

  return (
    <main className="container auth-layout">
      <section className="intro-column">
        <p className="brand">GuideRx</p>
        <h1>Clinician Portal</h1>
        <p>
          Access evidence summaries, recommendation histories, and patient-safe guidance in a
          secure clinical workspace.
        </p>
      </section>

      <section className="panel auth-panel" aria-label="Sign in panel">
        <h2>Sign in</h2>
        <p className="auth-subtitle">Use your organization-approved provider.</p>

        <div className="sso-grid">
          {(Object.keys(providerDetails) as FakeSsoProvider[]).map((provider) => {
            const details = providerDetails[provider];
            const isLoading = pendingProvider === provider;
            const isDisabled = pendingProvider !== null;

            return (
              <button
                key={provider}
                type="button"
                className={`sso-button ${details.accentClass}`}
                onClick={() => void handleSsoSignIn(provider)}
                disabled={isDisabled}
              >
                <span className="provider-icon" aria-hidden="true">
                  {details.icon}
                </span>
                <span>{isLoading ? "Redirecting..." : `Continue with ${details.label}`}</span>
              </button>
            );
          })}
        </div>

        <p className="help-text">Need access? Contact your GuideRx administrator.</p>
        <p className="disclaimer">
          Demo mode: this screen simulates OAuth and does not contact Google, Apple, or Microsoft.
        </p>
      </section>
    </main>
  );
}

export default App;
