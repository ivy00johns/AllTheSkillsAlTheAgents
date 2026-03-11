# Pact Consumer-Driven Contract Testing

Pact verifies that API consumers and providers agree on the interface. The consumer defines expectations; the provider verifies it meets them.

## When to Use Pact

- Multiple consumers of the same API
- Microservice architectures with independent deployments
- When contract drift is a recurring problem

For simple 2-agent builds (frontend + backend), static contract auditing is usually sufficient. Pact adds value when services evolve independently.

## Consumer Side (Frontend / API Client)

### JavaScript (Pact-JS)
```bash
npm install --save-dev @pact-foundation/pact
```

```typescript
import { PactV3, MatchersV3 } from '@pact-foundation/pact';

const provider = new PactV3({
  consumer: 'frontend',
  provider: 'backend-api',
});

describe('Sessions API', () => {
  it('creates a session', async () => {
    await provider
      .given('no existing sessions')
      .uponReceiving('a request to create a session')
      .withRequest({
        method: 'POST',
        path: '/api/v1/sessions',
        headers: { 'Content-Type': 'application/json' },
        body: { title: MatchersV3.string('Test Session') },
      })
      .willRespondWith({
        status: 201,
        headers: { 'Content-Type': 'application/json' },
        body: {
          id: MatchersV3.uuid(),
          title: MatchersV3.string(),
          createdAt: MatchersV3.iso8601DateTime(),
        },
      })
      .executeTest(async (mockServer) => {
        const response = await fetch(`${mockServer.url}/api/v1/sessions`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ title: 'Test Session' }),
        });
        expect(response.status).toBe(201);
      });
  });
});
```

### Python (Pact-Python)
```bash
pip install pact-python
```

```python
from pact import Consumer, Provider

pact = Consumer('frontend').has_pact_with(Provider('backend-api'))

def test_create_session():
    (pact
     .given('no existing sessions')
     .upon_receiving('a request to create a session')
     .with_request('POST', '/api/v1/sessions',
                   headers={'Content-Type': 'application/json'},
                   body={'title': 'Test Session'})
     .will_respond_with(201, body={
         'id': pact.Like('uuid-string'),
         'title': pact.Like('Test Session'),
         'createdAt': pact.Like('2024-01-01T00:00:00Z'),
     }))

    with pact:
        # Make actual request to mock server
        result = create_session(pact.uri, 'Test Session')
        assert result['id'] is not None
```

## Provider Side (Backend)

### Provider Verification
```typescript
import { Verifier } from '@pact-foundation/pact';

const opts = {
  providerBaseUrl: 'http://localhost:8000',
  pactUrls: ['./pacts/frontend-backend-api.json'],
  stateHandlers: {
    'no existing sessions': async () => {
      await db.clear('sessions');
    },
  },
};

new Verifier(opts).verifyProvider().then(() => {
  console.log('Pact verification complete');
});
```

## Pact Broker (CI/CD Integration)

```bash
# Publish pacts from consumer
pact-broker publish ./pacts \
  --consumer-app-version $(git rev-parse HEAD) \
  --broker-base-url https://your-broker.pactflow.io \
  --broker-token $PACT_TOKEN

# Verify on provider side
pact-broker can-i-deploy \
  --pacticipant backend-api \
  --version $(git rev-parse HEAD) \
  --to-environment production
```

## Workflow

1. Consumer writes Pact tests (defines expectations)
2. Running consumer tests generates a Pact file (JSON contract)
3. Pact file is shared with provider (file or Pact Broker)
4. Provider runs verification against the Pact file
5. Both sides pass → contract is satisfied

## Key Principles

- **Consumer-driven**: The consumer defines what it needs, not what the provider offers
- **Minimal contracts**: Only specify fields the consumer actually uses
- **Provider states**: Set up test data conditions before verification
- **Version pinning**: Track which consumer version works with which provider version
