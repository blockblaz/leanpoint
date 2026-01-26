import { Status } from '../types';

interface StatusCardProps {
  status: Status | null;
  loading: boolean;
  error: string | null;
}

export const StatusCard = ({ status, loading, error }: StatusCardProps) => {
  if (loading) {
    return <div className="loading">Loading status...</div>;
  }

  if (error) {
    return <div className="error-message">Error: {error}</div>;
  }

  if (!status) {
    return <div className="loading">No data available</div>;
  }

  const timeSinceUpdate = Date.now() - status.last_updated_ms;
  const timeSinceSuccess = Date.now() - status.last_success_ms;

  return (
    <>
      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-label">Finalized Slot</div>
          <div className="stat-value">{status.finalized_slot.toLocaleString()}</div>
          <div className="stat-subtitle">Latest finalized checkpoint</div>
        </div>

        <div className="stat-card">
          <div className="stat-label">Justified Slot</div>
          <div className="stat-value">{status.justified_slot.toLocaleString()}</div>
          <div className="stat-subtitle">Latest justified checkpoint</div>
        </div>

        <div className="stat-card">
          <div className="stat-label">Status</div>
          <div className="stat-value">
            <span className={`status-badge ${status.stale ? 'stale' : 'healthy'}`}>
              {status.stale ? 'Stale' : 'Fresh'}
            </span>
          </div>
          <div className="stat-subtitle">
            Updated {Math.floor(timeSinceUpdate / 1000)}s ago
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-label">Errors</div>
          <div className="stat-value">{status.error_count}</div>
          <div className="stat-subtitle">
            Last success {Math.floor(timeSinceSuccess / 1000)}s ago
          </div>
        </div>
      </div>

      {status.last_error && (
        <div className="error-message">
          <strong>Last Error:</strong> {status.last_error}
        </div>
      )}
    </>
  );
};
