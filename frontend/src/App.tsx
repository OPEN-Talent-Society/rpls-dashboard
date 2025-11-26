import { useEffect, useMemo, useState } from 'react'
import './App.css'
import type { CSSProperties } from 'react'

// Dev note: use explicit API base to avoid relative fetches when env is missing.
const API_BASE = (import.meta.env.VITE_API_BASE as string) || 'http://127.0.0.1:9055'

type MarketTemperature = {
  month: string
  hiring_rate: number
  attrition_rate: number
  trend: string
  history?: { month: string; hiring_rate: number; attrition_rate: number }[]
}

type SectorPulseEntry = {
  naics2d_code: string
  sector: string
  month: string
  prev_month: string
  employment?: number
  employment_pct_change?: number
  postings?: number
  postings_pct_change?: number
  salary?: number
  salary_pct_change?: number
  history?: {
    employment: number[]
    postings: number[]
    salary: number[]
  }
}

type SpotlightMover = {
  dimension: string
  sector?: string
  pct_change?: number | null
  history?: {
    employment?: number[]
  }
}

type Spotlight = { winners: SpotlightMover[]; losers: SpotlightMover[] }

type LayoffEntry = {
  state: string
  num_employees_laidoff: number
}

type HeatmapEntry = {
  state: string
  active_postings: number
  pct_change?: number | null
}

type PostingsHeatmap = {
  month: string
  prev_month: string
  data: HeatmapEntry[]
}

type GeminiResponse = {
  response: string
}

const Sparkline: React.FC<{ values: number[]; color: string; width?: number; height?: number }> = ({
  values,
  color,
  width = 90,
  height = 28,
}) => {
  if (!values.length) return null
  const max = Math.max(...values)
  const min = Math.min(...values)
  const range = max - min || 1
  const points = values
    .map((v, i) => {
      const x = (i / Math.max(1, values.length - 1)) * width
      const y = height - ((v - min) / range) * height
      return `${x},${y}`
    })
    .join(' ')
  return (
    <svg width={width} height={height} className="sparkline" aria-hidden>
      <polyline fill="none" stroke={color} strokeWidth="2" points={points} />
    </svg>
  )
}

const formatPct = (value?: number | string | null) => {
  if (value === undefined || value === null) return '—'
  const num = typeof value === 'string' ? Number(value) : value
  if (Number.isNaN(num)) return '—'
  return `${num.toFixed(2)}%`
}

function App() {
  const [dataVersion, setDataVersion] = useState<{ release?: string; ingestedAt?: string }>({})
  const [marketTemp, setMarketTemp] = useState<MarketTemperature | null>(null)
  const [spotlight, setSpotlight] = useState<Spotlight | null>(null)
  const [sectorPulse, setSectorPulse] = useState<SectorPulseEntry[]>([])
  const [layoffs, setLayoffs] = useState<LayoffEntry[]>([])
  const [postingsHeatmap, setPostingsHeatmap] = useState<PostingsHeatmap | null>(null)
  const [topMoversStrip, setTopMoversStrip] = useState<{ dimension: string; pct_change: number }[]>([])
  const [geminiQuestion, setGeminiQuestion] = useState('What changed most this month?')
  const [geminiContext, setGeminiContext] = useState(
    'You are summarizing RPLS labor stats for a people-ops audience. Keep answers concise.'
  )
  const [geminiReply, setGeminiReply] = useState<string>('')
  const [loadingGemini, setLoadingGemini] = useState(false)
  const [errors, setErrors] = useState<string | null>(null)

  const fetchJson = async <T,>(path: string, suppressError = false): Promise<T | null> => {
    try {
      const resp = await fetch(`${API_BASE}${path}`)
      if (!resp.ok) throw new Error(`Request failed: ${resp.status}`)
      return (await resp.json()) as T
    } catch (err) {
      console.error(err)
      if (!suppressError) setErrors(`Failed to fetch ${path}`)
      return null
    }
  }

  useEffect(() => {
    const load = async () => {
      const fallbackSeries = (series?: { value: number }[], fallback?: number | null) => {
        if (series && series.length) return series.map((x) => x.value ?? 0)
        const v = fallback ?? 0
        return [v, v]
      }

      const datasets = await fetchJson<{ datasets: any[] }>('/api/datasets', true)
      if (datasets?.datasets?.length) {
        const maxMonth = datasets.datasets
          .map((d) => d.max_month)
          .filter(Boolean)
          .sort()
          .pop()
        const ing = datasets.datasets.find((d) => d.ingested_at)?.ingested_at
        setDataVersion({
          release: maxMonth || undefined,
          ingestedAt: ing ? new Date(ing * 1000).toISOString() : undefined,
        })
      }

      const mt = await fetchJson<MarketTemperature>('/api/market-temperature')
      if (mt) {
        const hiringHist = await fetchJson<{ series: { month: string; value: number }[] }>(
          `/api/history?dimension_type=national&metric=hiring_rate&limit_months=6`,
          true
        )
        const attrHist = await fetchJson<{ series: { month: string; value: number }[] }>(
          `/api/history?dimension_type=national&metric=attrition_rate&limit_months=6`,
          true
        )
        mt.history =
          hiringHist && attrHist && hiringHist.series.length && attrHist.series.length
            ? hiringHist.series.map((h, i) => ({
                month: h.month,
                hiring_rate: h.value,
                attrition_rate: attrHist.series[i]?.value ?? attrHist.series.slice(-1)[0]?.value ?? h.value,
              }))
            : [
                {
                  month: mt.month,
                  hiring_rate: mt.hiring_rate ?? 0,
                  attrition_rate: mt.attrition_rate ?? 0,
                },
              ]
        setMarketTemp(mt)
      }

      const spot = await fetchJson<Spotlight>('/api/sector-spotlight')
      if (spot) {
        const winnersWithHist = await Promise.all(
          (spot.winners || []).map(async (w) => {
            const hist = await fetchJson<{ series: { value: number }[] }>(
              `/api/history?dimension_type=sector&metric=employment&id=${w.dimension}&limit_months=6`,
              true
            )
            return { ...w, history: { employment: hist?.series.map((x) => x.value ?? 0) || [] } }
          })
        )
        const losersWithHist = await Promise.all(
          (spot.losers || []).map(async (w) => {
            const hist = await fetchJson<{ series: { value: number }[] }>(
              `/api/history?dimension_type=sector&metric=employment&id=${w.dimension}&limit_months=6`,
              true
            )
            return { ...w, history: { employment: hist?.series.map((x) => x.value ?? 0) || [] } }
          })
        )
        setSpotlight({ winners: winnersWithHist, losers: losersWithHist })
      }

      const pulse = await fetchJson<SectorPulseEntry[]>('/api/sector-pulse')
      if (pulse) {
        const withHistory = await Promise.all(
          pulse.map(async (s) => {
            const emp = await fetchJson<{ series: { value: number }[] }>(
              `/api/history?dimension_type=sector&metric=employment&id=${s.naics2d_code}&limit_months=6`,
              true
            )
            const post = await fetchJson<{ series: { value: number }[] }>(
              `/api/history?dimension_type=sector&metric=postings&id=${s.naics2d_code}&limit_months=6`,
              true
            )
            const sal = await fetchJson<{ series: { value: number }[] }>(
              `/api/history?dimension_type=sector&metric=salary&id=${s.naics2d_code}&limit_months=6`,
              true
            )
            return {
              ...s,
              history: {
                employment: fallbackSeries(emp?.series, s.employment_pct_change),
                postings: fallbackSeries(post?.series, s.postings_pct_change),
                salary: fallbackSeries(sal?.series, s.salary_pct_change),
              },
            }
          })
        )
        setSectorPulse(withHistory)
      }

      const layoffsHeat = await fetchJson<{ month: string; data: LayoffEntry[] }>(
        '/api/layoffs-heatmap'
      )
      if (layoffsHeat) setLayoffs(layoffsHeat.data)

      const postings = await fetchJson<PostingsHeatmap>('/api/postings-heatmap')
      if (postings) setPostingsHeatmap(postings)

      const movers = await fetchJson<{ data: { dimension: string; pct_change: number }[] }>(
        '/api/top-movers?dimension_type=sector&metric=employment&count=6',
        true
      )
      if (movers?.data) setTopMoversStrip(movers.data)
    }
    load()
  }, [])

  const handleAskGemini = async () => {
    setLoadingGemini(true)
    setErrors(null)
    try {
      const resp = await fetch(`${API_BASE}/api/ask-gemini`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt: geminiQuestion, context: geminiContext }),
      })
      if (!resp.ok) throw new Error(`Gemini request failed: ${resp.status}`)
      const json: GeminiResponse = await resp.json()
      setGeminiReply(json.response)
    } catch (err) {
      console.error(err)
      setErrors('Gemini request failed')
    } finally {
      setLoadingGemini(false)
    }
  }

  const topLayoffStates = useMemo(() => {
    return layoffs
      .slice()
      .sort((a, b) => b.num_employees_laidoff - a.num_employees_laidoff)
      .slice(0, 5)
  }, [layoffs])

  const topSectorMoves = useMemo(() => {
    const withChange = sectorPulse.filter((s) => s.employment_pct_change !== null)
    const sorted = withChange.sort(
      (a, b) => (b.employment_pct_change || 0) - (a.employment_pct_change || 0)
    )
    return {
      top: sorted.slice(0, 4),
      bottom: sorted.slice(-4).reverse(),
    }
  }, [sectorPulse])

  const postingsLeaders = useMemo(() => {
    const data = postingsHeatmap?.data || []
    const sorted = data
      .filter((d) => d.pct_change !== null && d.pct_change !== undefined)
      .sort((a, b) => (b.pct_change || 0) - (a.pct_change || 0))
    return {
      top: sorted.slice(0, 5),
      bottom: sorted.slice(-5).reverse(),
    }
  }, [postingsHeatmap])

  const avgPostingsDelta = useMemo(() => {
    const data = postingsHeatmap?.data || []
    if (!data.length) return null
    const deltas = data.map((d) => d.pct_change || 0)
    return deltas.reduce((a, b) => a + b, 0) / deltas.length
  }, [postingsHeatmap])

  const topEmploymentMove = useMemo(() => topSectorMoves.top[0], [topSectorMoves])
  const bottomEmploymentMove = useMemo(() => topSectorMoves.bottom[0], [topSectorMoves])

  const tickerItems = useMemo(() => {
    const items: { label: string; value: string; tone?: string }[] = []
    if (marketTemp) {
      items.push({
        label: 'Hiring rate',
        value: formatPct(marketTemp.hiring_rate),
        tone: marketTemp.hiring_rate > marketTemp.attrition_rate ? 'up' : 'neutral',
      })
      items.push({
        label: 'Attrition rate',
        value: formatPct(marketTemp.attrition_rate),
        tone: marketTemp.attrition_rate > marketTemp.hiring_rate ? 'down' : 'neutral',
      })
    }
    if (avgPostingsDelta !== null) {
      items.push({
        label: 'Postings Δ',
        value: `${avgPostingsDelta.toFixed(2)}%`,
        tone: avgPostingsDelta >= 0 ? 'up' : 'down',
      })
    }
    if (topEmploymentMove?.sector) {
      items.push({
        label: `Hot: ${topEmploymentMove.sector}`,
        value: `${topEmploymentMove.employment_pct_change?.toFixed(2) ?? '—'}%`,
        tone: 'up',
      })
    }
    if (bottomEmploymentMove?.sector) {
      items.push({
        label: `Cool: ${bottomEmploymentMove.sector}`,
        value: `${bottomEmploymentMove.employment_pct_change?.toFixed(2) ?? '—'}%`,
        tone: 'down',
      })
    }
    return items
  }, [avgPostingsDelta, bottomEmploymentMove, marketTemp, topEmploymentMove])

  const barStyle = (
    pct?: number | null,
    tone: 'up' | 'down' | 'neutral' | 'postings' | 'salary' = 'neutral'
  ) => {
    const val = Math.abs(pct ?? 0)
    const width = Math.max(25, Math.min(100, Math.sqrt(val || 0) * 55))
    const toneColor =
      tone === 'up'
        ? '#67f5a8'
        : tone === 'down'
          ? '#f87171'
          : tone === 'postings'
            ? '#93b4ff'
            : tone === 'salary'
              ? '#e3c6ff'
              : '#9db4cc'
    return {
      '--bar-width': `${width}%`,
      '--bar-tone': toneColor,
    } as CSSProperties
  }

  return (
    <div className="page">
      <header className="hero">
        <div>
          <p className="eyebrow">Open Talent Society • RPLS</p>
          <h1>Labor Market Pulse</h1>
          <p className="lede">
            Quick snapshots of jobs, hiring, attrition, and salaries. Powered by OPEN Talent Society
            using the Revelio Public Labor Statistics datasets.
          </p>
        </div>
        <div className="badge">
          <span className="dot" /> Live prototype
        </div>
      </header>

      <div className="ticker">
        {tickerItems.length === 0 && <span className="muted">Waiting for data…</span>}
        {tickerItems.map((item, idx) => (
          <div key={item.label} className={`ticker-item ${item.tone || 'neutral'}`} style={{ animationDelay: `${idx * 0.05}s` }}>
            <span className="ticker-label">{item.label}</span>
            <span className="ticker-value">{item.value}</span>
          </div>
        ))}
      </div>
      <div className="legend">
        <div className="legend-chip emp">Employment Δ</div>
        <div className="legend-chip post">Postings Δ</div>
        <div className="legend-chip sal">Salary Δ</div>
        <div className="legend-note">Bars show magnitude vs last month; − on the left, + on the right.</div>
      </div>
      {dataVersion.release && (
        <div className="version-banner">
          Release: {dataVersion.release} {dataVersion.ingestedAt ? `• Ingested ${new Date(dataVersion.ingestedAt).toLocaleString()}` : ''}
        </div>
      )}
      {topMoversStrip.length > 0 && (
        <div className="mover-strip">
          {topMoversStrip.map((m, idx) => (
            <span key={m.dimension} className="mover-pill" style={{ animationDelay: `${idx * 0.03}s` }}>
              {m.dimension}: {m.pct_change?.toFixed(2) ?? '—'}%
            </span>
          ))}
        </div>
      )}

      {errors ? <div className="error">{errors}</div> : null}

      <section className="grid-hero">
        <div className="card hero-strip" style={{ ['--delay' as string]: '0s' }}>
          <div className="card-header">
            <h2>
              Market Temperature
              <span className="tip" title="Dual-line mini-chart: hiring vs attrition over recent months.">ℹ</span>
            </h2>
            <span className={`pill ${marketTemp?.trend || ''}`}>{marketTemp?.trend || '—'}</span>
          </div>
          <div className="metric-row">
            <div>
              <p className="metric-label">Month</p>
              <p className="metric-value">{marketTemp?.month || '—'}</p>
            </div>
            <div>
              <p className="metric-label">Hiring rate</p>
              <p className="metric-value">
                {marketTemp ? formatPct(marketTemp.hiring_rate) : '—'}
              </p>
            </div>
            <div>
              <p className="metric-label">Attrition rate</p>
              <p className="metric-value">
                {marketTemp ? formatPct(marketTemp.attrition_rate) : '—'}
              </p>
            </div>
          </div>
          <p className="hint">Higher hiring + attrition = dynamic; both down = cooling.</p>
          <div className="mini-bars">
            <div className="mini-bar">
              <span className="metric-label">Hiring</span>
              <span className="micro-bar" style={barStyle(marketTemp?.hiring_rate, 'up')} />
            </div>
            <div className="mini-bar">
              <span className="metric-label">Attrition</span>
              <span className="micro-bar" style={barStyle(marketTemp?.attrition_rate, 'down')} />
            </div>
            {marketTemp && (
              <div className="spark-dual">
                <Sparkline
                  values={
                    marketTemp.history?.length
                      ? marketTemp.history.map((h) => h.hiring_rate)
                      : [marketTemp.hiring_rate ?? 0]
                  }
                  color="#7ef0c9"
                  width={120}
                  height={32}
                />
                <Sparkline
                  values={
                    marketTemp.history?.length
                      ? marketTemp.history.map((h) => h.attrition_rate)
                      : [marketTemp.attrition_rate ?? 0]
                  }
                  color="#f87171"
                  width={120}
                  height={32}
                />
              </div>
            )}
          </div>
        </div>
        <div className="card guidance" style={{ ['--delay' as string]: '0.05s' }}>
          <div className="card-header">
            <h2>What you’re seeing</h2>
            <span className="pill neutral">MoM changes</span>
          </div>
          <ul className="list compact">
            <li className="list-row">
              <span className="muted">Source</span>
              <span>RPLS (Revelio) — national, sector, state.</span>
            </li>
            <li className="list-row">
              <span className="muted">MoM</span>
              <span>Month-over-month change vs prior month.</span>
            </li>
            <li className="list-row">
              <span className="muted">Color</span>
              <span>Employment = green/red; Postings = blue; Salary = violet.</span>
            </li>
            <li className="list-row">
              <span className="muted">Bars</span>
              <span>Magnitude of change; left is −, right is +.</span>
            </li>
            <li className="list-row">
              <span className="muted">Hover</span>
              <span>Cards lift with glow; tiles tint by direction.</span>
            </li>
          </ul>
        </div>
      </section>

      <section className="grid-main">
        <div className="card wide feature pulse-panel" style={{ ['--delay' as string]: '0.1s' }}>
            <div className="card-header">
              <h2>Sector Pulse</h2>
              <span className="pill neutral">Employment · Postings · Salary</span>
            </div>
            <div className="pulse-grid">
            {topSectorMoves.top.map((s) => (
              <div key={s.naics2d_code} className="pulse-tile up tile-up">
                <div className="tile-head">
                  <span className="muted">{s.naics2d_code}</span>
                  <strong>{s.sector}</strong>
                </div>
                <div className="bars">
                  <div>
                    <p className="metric-label">Employment</p>
                    <p className="delta up with-bar">
                      <span>{s.employment_pct_change?.toFixed(2) ?? '—'}%</span>
                      <span className="micro-bar" style={barStyle(s.employment_pct_change, 'up')} />
                    </p>
                  </div>
                  <div>
                    <p className="metric-label">Postings</p>
                    <p className="delta neutral with-bar">
                      <span>{s.postings_pct_change?.toFixed(2) ?? '—'}%</span>
                      <span className="micro-bar" style={barStyle(s.postings_pct_change, 'postings')} />
                    </p>
                  </div>
                  <div>
                    <p className="metric-label">Salary</p>
                    <p className="delta neutral with-bar">
                      <span>
                        {s.salary_pct_change !== null && s.salary_pct_change !== undefined
                          ? s.salary_pct_change.toFixed(2)
                          : '—'}
                        %
                      </span>
                      <span className="micro-bar" style={barStyle(s.salary_pct_change, 'salary')} />
                    </p>
                  </div>
                </div>
                <Sparkline
                  values={
                    s.history?.employment?.length
                      ? s.history.employment
                      : [s.employment_pct_change ?? 0]
                  }
                  color="#7ef0c9"
                />
              </div>
            ))}
            {topSectorMoves.bottom.map((s) => (
              <div key={s.naics2d_code} className="pulse-tile down tile-down">
                <div className="tile-head">
                  <span className="muted">{s.naics2d_code}</span>
                  <strong>{s.sector}</strong>
                </div>
                <div className="bars">
                  <div>
                    <p className="metric-label">Employment</p>
                    <p className="delta down with-bar">
                      <span>{s.employment_pct_change?.toFixed(2) ?? '—'}%</span>
                      <span className="micro-bar" style={barStyle(s.employment_pct_change, 'down')} />
                    </p>
                  </div>
                  <div>
                    <p className="metric-label">Postings</p>
                    <p className="delta neutral with-bar">
                      <span>{s.postings_pct_change?.toFixed(2) ?? '—'}%</span>
                      <span className="micro-bar" style={barStyle(s.postings_pct_change, 'postings')} />
                    </p>
                  </div>
                  <div>
                    <p className="metric-label">Salary</p>
                    <p className="delta neutral with-bar">
                      <span>
                        {s.salary_pct_change !== null && s.salary_pct_change !== undefined
                          ? s.salary_pct_change.toFixed(2)
                          : '—'}
                        %
                      </span>
                      <span className="micro-bar" style={barStyle(s.salary_pct_change, 'salary')} />
                    </p>
                  </div>
                </div>
                <Sparkline
                  values={
                    s.history?.employment?.length
                      ? s.history.employment
                      : [s.employment_pct_change ?? 0]
                  }
                  color="#f87171"
                />
              </div>
            ))}
          </div>
          <p className="hint">
            All deltas are MoM vs the prior month. Employment = headcount; Postings = active job ads; Salary = new posting pay.
          </p>
        </div>
        <div className="side-stack">
          <div className="card" style={{ ['--delay' as string]: '0.15s' }}>
            <div className="card-header">
              <h2>Sector Spotlight</h2>
              <span className="pill neutral">Top & bottom movers</span>
            </div>
            <div className="spotlight">
              <div>
                <p className="metric-label">
                  Winners (MoM) <span className="tip" title="Month over month employment change vs prior month.">ℹ</span>
                </p>
                <ul>
                  {spotlight?.winners?.map((item) => (
                    <li key={item.dimension} className="up">
                      <div>
                        <strong>{item.sector || item.dimension}</strong>
                        <div className="muted">Employment Δ MoM</div>
                      </div>
                      <div className="delta up with-bar">
                        <span>
                          {item.pct_change !== null && item.pct_change !== undefined
                            ? item.pct_change.toFixed(2)
                            : '—'}
                          %
                        </span>
                        <span className="micro-bar" style={barStyle(item.pct_change, 'up')} />
                      </div>
                      {item.history?.employment?.length ? (
                        <Sparkline values={item.history.employment} color="#7ef0c9" />
                      ) : null}
                    </li>
                  )) || <li className="muted">Loading…</li>}
                </ul>
              </div>
              <div>
                <p className="metric-label">
                  Losers (MoM) <span className="tip" title="Month over month employment change vs prior month.">ℹ</span>
                </p>
                <ul>
                  {spotlight?.losers?.map((item) => (
                    <li key={item.dimension} className="down">
                      <div>
                        <strong>{item.sector || item.dimension}</strong>
                        <div className="muted">Employment Δ MoM</div>
                      </div>
                      <div className="delta down with-bar">
                        <span>
                          {item.pct_change !== null && item.pct_change !== undefined
                            ? item.pct_change.toFixed(2)
                            : '—'}
                          %
                        </span>
                        <span className="micro-bar" style={barStyle(item.pct_change, 'down')} />
                      </div>
                      {item.history?.employment?.length ? (
                        <Sparkline values={item.history.employment} color="#f87171" />
                      ) : null}
                    </li>
                  )) || <li className="muted">Loading…</li>}
              </ul>
            </div>
          </div>
            <p className="hint">MoM = month over month change versus the prior month (RPLS employment).</p>
          </div>
          <div className="card" style={{ ['--delay' as string]: '0.2s' }}>
            <div className="card-header">
              <h2>Layoffs Snapshot</h2>
              <span className="pill warning">Latest month</span>
            </div>
            <ul className="list">
              {topLayoffStates.length === 0 && <li className="muted">Loading…</li>}
              {topLayoffStates.map((row) => (
                <li key={row.state} className="list-row">
                  <span>{row.state}</span>
                  <span className="muted">{row.num_employees_laidoff.toLocaleString()} layoffs</span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      <section className="grid-bottom">
        <div className="card" style={{ ['--delay' as string]: '0.22s' }}>
          <div className="card-header">
            <h2>Postings Momentum</h2>
            <span className="pill neutral">
              {postingsHeatmap ? postingsHeatmap.prev_month + ' → ' + postingsHeatmap.month : '—'}
            </span>
          </div>
          <div className="split">
            <div>
              <p className="metric-label">States gaining</p>
              <ul className="list">
                {postingsLeaders.top.length === 0 && (
                  <li className="list-row">
                    <span className="skeleton skeleton-line" style={{ width: '60%' }} />
                    <span className="skeleton skeleton-line" style={{ width: '30%' }} />
                  </li>
                )}
                {postingsLeaders.top.map((row) => (
                  <li key={row.state} className="list-row">
                    <span>{row.state}</span>
                    <span className="delta up with-bar">
                      <span>
                        {row.pct_change !== null && row.pct_change !== undefined
                          ? row.pct_change.toFixed(2) + '%'
                          : '—'}
                      </span>
                      <span className="micro-bar" style={barStyle(row.pct_change, 'up')} />
                    </span>
                  </li>
                ))}
              </ul>
            </div>
            <div>
              <p className="metric-label">States cooling</p>
              <ul className="list">
                {postingsLeaders.bottom.length === 0 && (
                  <li className="list-row">
                    <span className="skeleton skeleton-line" style={{ width: '60%' }} />
                    <span className="skeleton skeleton-line" style={{ width: '30%' }} />
                  </li>
                )}
                {postingsLeaders.bottom.map((row) => (
                  <li key={row.state} className="list-row">
                    <span>{row.state}</span>
                    <span className="delta down with-bar">
                      <span>
                        {row.pct_change !== null && row.pct_change !== undefined
                          ? row.pct_change.toFixed(2) + '%'
                          : '—'}
                      </span>
                      <span className="micro-bar" style={barStyle(row.pct_change, 'down')} />
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>

        <div className="card gemini" style={{ ['--delay' as string]: '0.25s' }}>
          <div className="card-header">
            <h2>RPLS Explainer (Gemini)</h2>
            <span className="pill neutral">Short answers</span>
          </div>
          <label className="field">
            <span>Question</span>
            <input
              value={geminiQuestion}
              onChange={(e) => setGeminiQuestion(e.target.value)}
              placeholder="Ask about sectors, states, salaries…"
            />
          </label>
          <label className="field">
            <span>Context</span>
            <textarea
              value={geminiContext}
              onChange={(e) => setGeminiContext(e.target.value)}
              rows={3}
            />
          </label>
          <button className="primary" onClick={handleAskGemini} disabled={loadingGemini}>
            {loadingGemini ? 'Asking…' : 'Ask Gemini'}
          </button>
          {geminiReply && <p className="response">{geminiReply}</p>}
        </div>
      </section>
    </div>
  )
}

export default App
