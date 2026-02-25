/**
 * Reminder Service
 * Sends an initial webhook POST to n8n on login/signup to register the user.
 *
 * The actual timed reminders (15min, 4hrs, 17hrs, 40hrs) are handled
 * server-side by pg_cron in Supabase, so they persist even if the user
 * logs out or closes the browser. The pg_cron job calls
 * process_document_reminders() every 5 minutes, which:
 *   - Checks if documentation_status is already 'Complete' (skips if so)
 *   - Fires a webhook to n8n for each due reminder
 *   - Marks the reminder as sent
 *
 * This client-side service only sends the initial "user logged in" event
 * so n8n knows about the session. The server-side reminders are independent.
 */

const REMINDER_WEBHOOK_URL = 'https://davidvanwachem.app.n8n.cloud/webhook/get-website-filled-status';

/**
 * Notify n8n that a user has logged in and may need document reminders.
 * Server-side pg_cron handles the actual timed reminders at:
 *   - 15 minutes
 *   - 4 hours
 *   - 17 hours
 *   - 40 hours
 *
 * @param {string} phoneNumber - User's phone number (with country code)
 * @param {string} dossierId - User's dossier ID
 */
export const sendReminderRegistration = async (phoneNumber, dossierId) => {
    const payload = {
        eventType: 'document_reminder',
        phoneNumber,
        dossierId,
        loginTimestamp: new Date().toISOString(),
    };

    console.log('[Reminder] Sending reminder registration to n8n:', payload);

    try {
        const response = await fetch(REMINDER_WEBHOOK_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });

        if (response.ok) {
            console.log('[Reminder] Successfully registered for reminders');
        } else {
            console.error(`[Reminder] Failed to register: HTTP ${response.status}`);
        }
    } catch (error) {
        console.error('[Reminder] Network error:', error);
    }
};
