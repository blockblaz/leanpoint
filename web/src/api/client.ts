import { Status, UpstreamsResponse } from '../types';

const API_BASE = '';

export async function fetchStatus(): Promise<Status> {
  const response = await fetch(`${API_BASE}/status`);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
  return response.json();
}

export async function fetchUpstreams(): Promise<UpstreamsResponse> {
  const response = await fetch(`${API_BASE}/api/upstreams`);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
  return response.json();
}

export async function fetchHealth(): Promise<{ healthy: boolean }> {
  const response = await fetch(`${API_BASE}/healthz`);
  return { healthy: response.ok };
}
