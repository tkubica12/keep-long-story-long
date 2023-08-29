# Container to play with probes

| API |  Description |
| --- | --- |
| / | Returns 200 if healthy and ready, returns 200 after 15 seconds if healty but not ready, hangs if not healthy |
| /health | Returns 200 if healthy, generates load and returns nothing if not |
| /readiness | Returns 200 if ready, returns 503 if not |
| /setReady | Sets ready state to true |
| /setNotReady | Sets ready state to false |
| /kill | Kills app|
| /hang | Stop responding to health probes |