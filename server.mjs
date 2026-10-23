import http from 'node:http';

const apiKey = process.env.OPENAI_API_KEY;
const token = process.env.ALEX_APP_TOKEN || '';
const port = Number(process.env.PORT || 8080);
const model = process.env.OPENAI_MODEL || 'gpt-4.1-mini';
if (!apiKey) { console.error('Set OPENAI_API_KEY before starting.'); process.exit(1); }
const basePrompt = `You are Alex 2.0, a personable AI assistant for Johnny. Be friendly, witty, technically competent, and clear. You are software, not a human. Converse on any topic within normal safety boundaries. Don't claim memories or capabilities you lack. Your creator is Johnny; you support his OhmLoom and RepairLens ambitions. Speak naturally because answers may be read aloud. Avoid overlong answers.`;
const investorPrompt = `Investor mode: Introduce yourself as Alex 2.0, a demonstration AI companion for Johnny's OhmLoom / RepairLens concept. RepairLens is a proposed augmented-reality repair assistant for electronics, automotive, and small engines, with component identification, circuit and wiring guidance, measurement-aware diagnosis, fault-path visualization, safety support and repair steps. Early hardware concept: off-the-shelf AR glasses and portable computer; long-term integrated headset. Smart-ring pointing is a future concept. Prototype and feasibility are in development. Explain possible use cases, demonstrate conversational abilities, and answer questions candidly. Do NOT imply validated production costs, completed patents, proven AR tracking, committed funding, guaranteed investor repayment, or tested hardware integrations. Never make up financial projections.`;

const server = http.createServer(async (req, res) => {
  const respond = (status, body) => { res.writeHead(status, {'Content-Type':'application/json', 'Cache-Control':'no-store'}); res.end(JSON.stringify(body)); };
  if (req.url === '/health' && req.method === 'GET') return respond(200, {ok:true});
  if (req.url !== '/chat' || req.method !== 'POST') return respond(404, {error:'Not found'});
  if (token && req.headers.authorization !== `Bearer ${token}`) return respond(401, {error:'Unauthorized'});
  let raw = '';
  try {
    for await (const chunk of req) { raw += chunk; if (raw.length > 100_000) throw new Error('Request too large'); }
    const input = JSON.parse(raw);
    if (!Array.isArray(input.messages)) return respond(400, {error:'Invalid messages'});
    const history = input.messages.slice(-20).filter(x => ['user','assistant'].includes(x.role) && typeof x.content === 'string').map(x => ({role:x.role, content:x.content.slice(0,4000)}));
    const r = await fetch('https://api.openai.com/v1/responses', {
      method:'POST',
      headers:{'Authorization':`Bearer ${apiKey}`, 'Content-Type':'application/json'},
      body: JSON.stringify({model, instructions: basePrompt + (input.investorMode ? '\n' + investorPrompt : ''), input: history, max_output_tokens: 650})
    });
    const result = await r.json();
    if (!r.ok) { console.error('AI provider error', r.status, result.error?.message); return respond(502,{error:'AI provider error'}); }
    const reply = (result.output || []).flatMap(o => o.content || []).filter(c => c.type === 'output_text').map(c => c.text).join('\n').trim();
    if (!reply) return respond(502, {error:'Empty AI response'});
    return respond(200, {reply});
  } catch (e) { console.error(e); return respond(400,{error:'Invalid request'}); }
});
server.listen(port, '0.0.0.0', () => console.log(`Alex backend listening on ${port}`));
