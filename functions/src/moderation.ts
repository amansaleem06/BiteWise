import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { onCall, HttpsError } from "firebase-functions/v2/https";

/** Admin-only report resolution, with an immutable audit record. */
export const resolveReport = onCall(async request => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const db = getFirestore();
  const admin = await db.doc('users/' + request.auth.uid).get();
  if (admin.data()?.role !== 'admin') throw new HttpsError('permission-denied', 'Moderator access required.');
  const { reportId, action, note } = request.data ?? {};
  if (typeof reportId !== 'string' || !reportId || reportId.includes('/') || reportId.length > 1500 ||
      !['dismiss', 'hide', 'suspend'].includes(action) || typeof note !== 'string' || !note.trim() || note.length > 2000) {
    throw new HttpsError('invalid-argument', 'Provide reportId, action (dismiss/hide/suspend), and review note.');
  }
  const reportRef = db.doc('reports/' + reportId);
  const auditRef = db.collection('moderationAudit').doc();
  const result = await db.runTransaction(async transaction => {
    const reportSnap = await transaction.get(reportRef);
    if (!reportSnap.exists) throw new HttpsError('not-found', 'Report not found.');
    const report = reportSnap.data()!;
    if (report.status !== 'open') return { alreadyResolved: true, targetUserId: report.targetUserId as string };
    let targetPath: string | undefined;
    if (action === 'hide') {
      if (report.targetType === 'post') targetPath = 'posts/' + report.targetId;
      if (report.targetType === 'story') targetPath = 'stories/' + report.targetId;
      if (report.targetType === 'comment' && new RegExp('^(posts|stories)/[^/]+/comments/[^/]+$').test(report.targetId)) targetPath = report.targetId;
      if (!targetPath || !new RegExp('^(posts|stories)/[^/]+(/comments/[^/]+)?$').test(targetPath)) {
        throw new HttpsError('failed-precondition', 'This report has no removable content path. Review the conversation/account instead.');
      }
      const target = await transaction.get(db.doc(targetPath));
      if (!target.exists || target.data()?.authorId !== report.targetUserId) {
        throw new HttpsError('failed-precondition', 'Content missing or reported author does not match.');
      }
    }
    if (action === 'suspend') {
      if (typeof report.targetUserId !== 'string' || report.targetUserId.includes('/')) throw new HttpsError('invalid-argument', 'Invalid account.');
      const target = await transaction.get(db.doc('users/' + report.targetUserId));
      if (!target.exists || target.data()?.role === 'admin') throw new HttpsError('failed-precondition', 'Account cannot be suspended here.');
    }
    if (targetPath) transaction.update(db.doc(targetPath), { moderationHidden: true });
    if (action === 'suspend') transaction.update(db.doc('users/' + report.targetUserId), { suspended: true });
    const record = { reportId, action, note: note.trim(), moderatorId: request.auth!.uid, reviewedAt: FieldValue.serverTimestamp() };
    transaction.update(reportRef, { status: action === 'dismiss' ? 'dismissed' : 'actioned', ...record });
    transaction.create(auditRef, record);
    return { alreadyResolved: false, targetUserId: report.targetUserId as string };
  });
  // Firestore suspension is immediate, even if Auth is temporarily unavailable.
  // Repeating suspend retries disabling Auth safely without duplicate audit writes.
  if (action === 'suspend') {
    const target = await db.doc('users/' + result.targetUserId).get();
    if (target.data()?.suspended === true) {
      await getAuth().updateUser(result.targetUserId, { disabled: true });
      await getAuth().revokeRefreshTokens(result.targetUserId);
    }
  }
  return { ok: true, alreadyResolved: result.alreadyResolved };
});
