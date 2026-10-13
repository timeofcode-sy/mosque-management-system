# Security review report

## Summary

**Result: one confirmed high-severity cross-institute authorization flaw.**

Authenticated users with `reports.view` in their active institute can request print
reports for records belonging to another institute by supplying those records'
identifiers. The route permission is checked, but the report controller does not
scope its bound models to the active institute or verify their institute ownership.

## Scope and method

- Reviewed the Laravel web routes and print-report controller for tenant-boundary
  enforcement.
- Ran a non-destructive feature-test probe against the local Laravel test database.
- Attempted to reach `nuzuln.com` for live HTTP checks; DNS resolution was unavailable
  in the execution environment, so no production requests or response-header checks
  were completed.
- No brute-force, load, destructive, or production data-modification tests were run.

## Finding

### HIGH — Cross-institute access to print reports

Routes protected by `permission:reports.view` accept a `CourseCircle`, `Shift`, or
`Student` through implicit model binding. The corresponding actions render reports
from those models without checking that each record belongs to the institute active
in the user's session. As a result, an authenticated user authorized to view reports
in Institute A can change the record identifier in the URL to one from Institute B.

The local probe used a user authorized for reports in one institute and records
created for a second institute. All four requests returned HTTP 200 rather than the
expected denial:

| Route | Controller action | Result |
|---|---|---:|
| `reports.print.circle` | `circleDaily` | 200 |
| `reports.print.points` | `circlePoints` | 200 |
| `reports.print.shift` | `shiftRanking` | 200 |
| `reports.print.student` | `student` | 200 |

**Affected code:** `backend/app/Http/Controllers/ReportPrintController.php`
(actions `circleDaily`, `circlePoints`, `shiftRanking`, and `student`); routes are
defined in `backend/routes/web.php` under the `reports.view` permission group.

**Impact:** Exposure of report data across institute boundaries, potentially
including student profile, attendance, progress, and ranking information.

**Recommended remediation:** Resolve the active institute for the authenticated
user and enforce ownership for each requested model before building the report.
Return 404 for records outside that institute. Add regression tests covering
cross-institute denial and access to records in the active institute.

**Confidence:** 10/10. This was reproduced across all four routes using the local
Laravel feature-test environment. The live deployment was not tested.

## Checks not completed

- Production security headers and cookie attributes could not be inspected because
  `nuzuln.com` did not resolve from the test environment.
- The report documents a local application-level finding; it is not a certification
  or a complete assessment of the deployed site's infrastructure.
