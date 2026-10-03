# Laravel contract fixtures

These deterministic, sanitized examples preserve fields/assertions from
`~/Documents/web/phplaravel/flixquest-backend`. They are not production exports.
IDs, timestamps, credentials and network configuration use safe literal values.

| Fixture | Executable contract source |
|---|---|
| `user.json` | `app/Http/Resources/V1/UserResource.php` |
| `auth.json` | `tests/Feature/AuthTest.php`: registration/login success envelope, plus UserResource |
| `validation_error.json` | `tests/Feature/ApiErrorEnvelopeTest.php`: validation envelope |
| `clock_skew_error.json` | `tests/Feature/SyncEngineTest.php`: skew rejection; `app/Http/Responses/ApiExceptionRenderer.php` |
| `bootstrap.json` | `tests/Feature/ConfigBootstrapTest.php`: seeded defaults; `ConfigController::buildBootstrapData` |
| `ads.json` | `tests/Feature/BannerAdTest.php`: camelCase ad contract |
| `sync.json` | `tests/Feature/MobileCompatibilityTest.php`: time aliases; `MigrationReadinessTest.php` and `RecentlyWatchedSyncController.php`: revisions/empty pull |

The bootstrap, ads and sync fixtures are retained for tests in the phases that own
those DTOs. Update fixtures against backend resources and Pest assertions whenever
a wire contract changes; never paste live tokens or configuration secrets here.
