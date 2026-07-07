/// Page size for all project listing UIs (agreement, filters, charts, etc.).
const int kProjectsListPageSize = 10;

/// Max in-progress projects loaded for dashboard chart / status pre-filters.
const int kProjectsDashboardMaxProjects = 40;

/// Higher cap for management portfolio on the dashboard chart.
const int kProjectsDashboardManagementMaxProjects = kProjectsGroupHubMaxProjects;

/// Page size when accumulating dashboard/map project samples.
const int kProjectsBulkFetchPageSize = 40;

/// Max projects loaded on the portfolio map.
const int kProjectsMapMaxProjects = 200;

/// Max projects loaded for group-by hub aggregation (filter → group).
const int kProjectsGroupHubMaxProjects = 600;
