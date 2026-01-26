export interface Status {
  justified_slot: number;
  finalized_slot: number;
  last_updated_ms: number;
  last_success_ms: number;
  stale: boolean;
  error_count: number;
  last_error: string | null;
}

export interface Upstream {
  name: string;
  url: string;
  path: string;
  healthy: boolean;
  last_success_ms: number | null;
  error_count: number;
  last_error: string | null;
  last_justified_slot: number | null;
  last_finalized_slot: number | null;
}

export interface UpstreamsResponse {
  upstreams: Upstream[];
  consensus: {
    total_upstreams: number;
    responding_upstreams: number;
    consensus_threshold: number;
    has_consensus: boolean;
  };
}

export interface HistoricalCheckpoint {
  slot: number;
  timestamp: number;
  finalized: boolean;
}
