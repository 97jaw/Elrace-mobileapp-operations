const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const {
  buildTimesheetApprovalNotifyPlan,
} = require("./timesheet_approval_notify");

const DOC_ID = "ta-1";

function baseDoc({
  status = "pending",
  seStatus = "pending",
  pmStatus = "pending",
  withPm = true,
} = {}) {
  const approvers = {
    "se-uid": {
      role: "site_engineer",
      name: "Sam Engineer",
      status: seStatus,
    },
  };
  const approver_uids = ["se-uid"];
  const pending_uids = [];
  if (seStatus === "pending") pending_uids.push("se-uid");
  if (withPm) {
    approvers["pm-uid"] = {
      role: "projects_manager",
      name: "Pat Manager",
      status: pmStatus,
    };
    approver_uids.push("pm-uid");
    if (pmStatus === "pending") pending_uids.push("pm-uid");
  }
  return {
    owner_uid: "foreman-uid",
    owner_name: "Fran Foreman",
    file_name: "Site A.pdf",
    project_name: "Tower",
    status,
    approver_uids,
    pending_uids,
    approvers,
  };
}

describe("buildTimesheetApprovalNotifyPlan", () => {
  it("created → waiting push to every approver (not stored)", () => {
    const after = baseDoc();
    const plan = buildTimesheetApprovalNotifyPlan(null, after, DOC_ID);
    assert.equal(plan.kind, "waiting");
    assert.equal(plan.store, false);
    assert.deepEqual(plan.recipientUids, ["se-uid", "pm-uid"]);
    assert.equal(plan.title, "Timesheet waiting for your approval");
    assert.equal(plan.body, "Fran Foreman sent Site A.pdf · Tower");
    assert.equal(plan.type, "timesheet_approval.waiting");
    assert.equal(plan.category, "timesheet_approval_waiting");
    assert.equal(plan.eventId, "ta-1:waiting");
  });

  it("created with one approver and no project", () => {
    const after = baseDoc({ withPm: false });
    after.project_name = "";
    const plan = buildTimesheetApprovalNotifyPlan(null, after, DOC_ID);
    assert.deepEqual(plan.recipientUids, ["se-uid"]);
    assert.equal(plan.body, "Fran Foreman sent Site A.pdf");
  });

  it("SE approved while still pending → partial to owner", () => {
    const before = baseDoc();
    const after = baseDoc({ seStatus: "approved", pmStatus: "pending" });
    const plan = buildTimesheetApprovalNotifyPlan(before, after, DOC_ID);
    assert.equal(plan.kind, "approved_partial");
    assert.equal(plan.store, true);
    assert.deepEqual(plan.recipientUids, ["foreman-uid"]);
    assert.equal(
      plan.title,
      "Approved by Sam Engineer (Site Engineer)"
    );
    assert.equal(plan.body, "Site A.pdf — waiting for Pat Manager");
    assert.equal(plan.type, "timesheet_approval.approved");
    assert.equal(plan.category, "timesheet_approval");
    assert.equal(plan.eventId, "ta-1:approved:se-uid");
  });

  it("second approval → only fully approved (not partial)", () => {
    const before = baseDoc({ seStatus: "approved", pmStatus: "pending" });
    const after = baseDoc({
      status: "approved",
      seStatus: "approved",
      pmStatus: "approved",
    });
    const plan = buildTimesheetApprovalNotifyPlan(before, after, DOC_ID);
    assert.equal(plan.kind, "approved_all");
    assert.equal(plan.store, true);
    assert.equal(plan.title, "Timesheet approved");
    assert.match(plan.body, /Site A\.pdf approved by/);
    assert.match(plan.body, /Sam Engineer/);
    assert.match(plan.body, /Pat Manager/);
    assert.equal(plan.eventId, "ta-1:approved:all");
    assert.equal(plan.type, "timesheet_approval.approved");
  });

  it("single approver create→approve → fully approved", () => {
    const before = baseDoc({ withPm: false });
    const after = baseDoc({
      withPm: false,
      status: "approved",
      seStatus: "approved",
    });
    const plan = buildTimesheetApprovalNotifyPlan(before, after, DOC_ID);
    assert.equal(plan.kind, "approved_all");
    assert.equal(plan.body, "Site A.pdf approved by Sam Engineer");
  });

  it("reject → rejected to owner with stable event id", () => {
    const before = baseDoc();
    const after = baseDoc({
      status: "rejected",
      seStatus: "rejected",
      pmStatus: "pending",
    });
    after.pending_uids = [];
    const plan = buildTimesheetApprovalNotifyPlan(before, after, DOC_ID);
    assert.equal(plan.kind, "rejected");
    assert.equal(plan.store, true);
    assert.equal(plan.title, "Timesheet rejected");
    assert.equal(
      plan.body,
      "Sam Engineer (Site Engineer) rejected Site A.pdf"
    );
    assert.equal(plan.type, "timesheet_approval.rejected");
    assert.equal(plan.eventId, "ta-1:rejected:se-uid");
  });

  it("retry-safe: same inputs produce the same eventId", () => {
    const before = baseDoc();
    const after = baseDoc({ seStatus: "approved", pmStatus: "pending" });
    const a = buildTimesheetApprovalNotifyPlan(before, after, DOC_ID);
    const b = buildTimesheetApprovalNotifyPlan(before, after, DOC_ID);
    assert.equal(a.eventId, b.eventId);
    assert.equal(a.eventId, "ta-1:approved:se-uid");
  });

  it("no-op when nothing meaningful changed", () => {
    const doc = baseDoc();
    assert.equal(buildTimesheetApprovalNotifyPlan(doc, doc, DOC_ID), null);
  });
});
