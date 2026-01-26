import { UpstreamsResponse } from '../types';

interface UpstreamsTableProps {
  data: UpstreamsResponse | null;
  loading: boolean;
  error: string | null;
}

export const UpstreamsTable = ({ data, loading, error }: UpstreamsTableProps) => {
  if (loading) {
    return <div className="loading">Loading upstreams...</div>;
  }

  if (error) {
    return <div className="error-message">Error: {error}</div>;
  }

  if (!data || data.upstreams.length === 0) {
    return <div className="loading">No upstreams configured</div>;
  }

  const formatTime = (ms: number | null) => {
    if (!ms) return 'Never';
    const seconds = Math.floor((Date.now() - ms) / 1000);
    if (seconds < 60) return `${seconds}s ago`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    return `${Math.floor(seconds / 3600)}h ago`;
  };

  return (
    <>
      {data.consensus && (
        <div className="consensus-info">
          <div className="consensus-item">
            <span className="consensus-label">Total Upstreams</span>
            <span className="consensus-value">{data.consensus.total_upstreams}</span>
          </div>
          <div className="consensus-item">
            <span className="consensus-label">Responding</span>
            <span className="consensus-value">{data.consensus.responding_upstreams}</span>
          </div>
          <div className="consensus-item">
            <span className="consensus-label">Threshold</span>
            <span className="consensus-value">{data.consensus.consensus_threshold}%</span>
          </div>
          <div className="consensus-item">
            <span className="consensus-label">Consensus</span>
            <span className="consensus-value">
              <span className={`status-badge ${data.consensus.has_consensus ? 'healthy' : 'unhealthy'}`}>
                {data.consensus.has_consensus ? 'Reached' : 'Not Reached'}
              </span>
            </span>
          </div>
        </div>
      )}

      <table className="upstreams-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Status</th>
            <th>Finalized</th>
            <th>Justified</th>
            <th>Errors</th>
            <th>Last Success</th>
          </tr>
        </thead>
        <tbody>
          {data.upstreams.map((upstream) => (
            <tr key={upstream.name}>
              <td>
                <div className="upstream-name">{upstream.name}</div>
                <div className="upstream-url">{upstream.url}</div>
              </td>
              <td>
                <span className={`status-badge ${upstream.healthy ? 'healthy' : 'unhealthy'}`}>
                  {upstream.healthy ? 'Healthy' : 'Unhealthy'}
                </span>
              </td>
              <td>
                {upstream.last_finalized_slot !== null
                  ? upstream.last_finalized_slot.toLocaleString()
                  : 'N/A'}
              </td>
              <td>
                {upstream.last_justified_slot !== null
                  ? upstream.last_justified_slot.toLocaleString()
                  : 'N/A'}
              </td>
              <td>{upstream.error_count}</td>
              <td>{formatTime(upstream.last_success_ms)}</td>
            </tr>
          ))}
        </tbody>
      </table>

      {data.upstreams.some((u) => u.last_error) && (
        <div style={{ marginTop: '1rem' }}>
          {data.upstreams
            .filter((u) => u.last_error)
            .map((upstream) => (
              <div key={upstream.name} className="error-message" style={{ marginBottom: '0.5rem' }}>
                <strong>{upstream.name}:</strong> {upstream.last_error}
              </div>
            ))}
        </div>
      )}
    </>
  );
};
