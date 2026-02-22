/**
 * Apartment Webhook Service
 * Functions to trigger webhooks when apartment status changes
 * Call these functions after updating/inserting apartments in your code
 * 
 * Usage:
 *   import { updateApartmentWithWebhook, insertApartmentWithWebhook } from './services/apartmentWebhookService';
 *   import { supabase } from './integrations/supabase/client';
 * 
 *   // Update apartment (automatically triggers webhooks)
 *   const result = await updateApartmentWithWebhook(supabase, apartmentId, { status: 'CreateLink' });
 * 
 *   // Insert apartment (automatically triggers webhooks)
 *   const result = await insertApartmentWithWebhook(supabase, apartmentData);
 */

// Webhook URLs
const CREATE_LINK_WEBHOOK_URL = 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
const ACTIVE_WEBHOOK_URL = 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active';

const MAX_RETRIES = 3;
const INITIAL_RETRY_DELAY = 1000;

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

/**
 * Fetch with retry logic
 */
const fetchWithRetry = async (url, options, retries = MAX_RETRIES) => {
    for (let attempt = 0; attempt <= retries; attempt++) {
        try {
            const response = await fetch(url, options);

            if (response.ok) {
                return { ok: true, response };
            }

            if (response.status >= 500 && attempt < retries) {
                const delay = INITIAL_RETRY_DELAY * Math.pow(2, attempt);
                console.log(`[ApartmentWebhook] Server error ${response.status}, retrying in ${delay / 1000}s (attempt ${attempt + 1}/${retries})`);
                await sleep(delay);
                continue;
            }

            return { ok: false, message: `HTTP ${response.status}`, response };
        } catch (error) {
            if (attempt < retries) {
                const delay = INITIAL_RETRY_DELAY * Math.pow(2, attempt);
                console.log(`[ApartmentWebhook] Network error, retrying in ${delay / 1000}s (attempt ${attempt + 1}/${retries}):`, error.message);
                await sleep(delay);
                continue;
            }
            return { ok: false, message: error.message, error };
        }
    }
    return { ok: false, message: 'Max retries exceeded' };
};

/**
 * Get matched tenants for an apartment based on tags
 * @param {Object} supabase - Supabase client instance
 * @param {string} apartmentId - Apartment UUID
 * @param {Array<string>} apartmentTags - Array of apartment tags
 * @returns {Promise<Array>} Array of matched tenant accounts
 */
const getMatchedTenants = async (supabase, apartmentId, apartmentTags) => {
    if (!apartmentTags || apartmentTags.length === 0) {
        return [];
    }

    try {
        const { data: accounts, error } = await supabase
            .from('accounts')
            .select('*')
            .not('tags', 'is', null);

        if (error) {
            console.error('[ApartmentWebhook] Error fetching accounts:', error);
            return [];
        }

        // Filter accounts where tags overlap with apartment tags
        const matchedAccounts = (accounts || []).filter(account => {
            if (!account.tags || account.tags.length === 0) {
                return false;
            }
            // Check if any tag overlaps
            return apartmentTags.some(aptTag => account.tags.includes(aptTag));
        });

        // Format matched accounts
        return matchedAccounts.map(account => ({
            account_id: account.id,
            tenant_name: account.tenant_name,
            whatsapp_number: account.whatsapp_number,
            email: account.email,
            tags: account.tags,
            preferred_location: account.preferred_location,
            move_in_date: account.move_in_date,
            work_status: account.work_status,
            monthly_income: account.monthly_income,
            salesforce_account_id: account.salesforce_account_id,
            status: account.status,
            documentation_status: account.documentation_status
        }));
    } catch (error) {
        console.error('[ApartmentWebhook] Error getting matched tenants:', error);
        return [];
    }
};

/**
 * Get real estate agent info
 * @param {Object} supabase - Supabase client instance
 * @param {string} agentId - Real estate agent UUID
 * @returns {Promise<Object|null>} Agent object or null
 */
const getRealEstateAgent = async (supabase, agentId) => {
    if (!agentId) {
        return null;
    }

    try {
        const { data: agent, error } = await supabase
            .from('real_estate_agents')
            .select('*')
            .eq('id', agentId)
            .single();

        if (error || !agent) {
            return null;
        }

        return {
            id: agent.id,
            name: agent.name,
            phone_number: agent.phone_number,
            picture_url: agent.picture_url
        };
    } catch (error) {
        console.error('[ApartmentWebhook] Error fetching real estate agent:', error);
        return null;
    }
};

/**
 * Send CreateLink webhook
 * Triggers when apartment status changes to 'CreateLink'
 * @param {Object} supabase - Supabase client instance
 * @param {Object} apartment - Complete apartment object with all fields
 * @param {string} oldStatus - Previous status (optional, for UPDATE operations)
 * @returns {Promise<{ok: boolean, error?: string}>}
 */
export const sendCreateLinkWebhook = async (supabase, apartment, oldStatus = null) => {
    // Get status (handle both "Status" and "status" column names)
    const newStatus = apartment.Status || apartment.status;
    
    // Only trigger if status is 'CreateLink' and it changed
    if (newStatus !== 'CreateLink' || (oldStatus && oldStatus === 'CreateLink')) {
        return { ok: true, skipped: true };
    }

    try {
        // Get real estate agent info
        const agentId = apartment.real_estate_agent_id || apartment['Real Estate Agent Id'];
        const realEstateAgent = await getRealEstateAgent(supabase, agentId);

        // Build payload with ALL apartment data
        const payload = {
            ...apartment, // Include all apartment fields
            real_estate_agent: realEstateAgent,
            timestamp: new Date().toISOString(),
            event_type: 'apartment_status_create_link',
            trigger_operation: oldStatus !== null ? 'UPDATE' : 'INSERT'
        };

        console.log('[ApartmentWebhook] Sending CreateLink webhook for apartment:', apartment.id);

        const result = await fetchWithRetry(CREATE_LINK_WEBHOOK_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(payload)
        });

        if (result.ok) {
            console.log('[ApartmentWebhook] ✅ CreateLink webhook sent successfully');
            return { ok: true };
        } else {
            console.error('[ApartmentWebhook] ❌ CreateLink webhook failed:', result.message);
            return { ok: false, error: result.message };
        }
    } catch (error) {
        console.error('[ApartmentWebhook] Error sending CreateLink webhook:', error);
        return { ok: false, error: error.message };
    }
};

/**
 * Send Active webhook
 * Triggers when apartment status changes to 'Active'
 * Includes matched tenants based on tags
 * @param {Object} supabase - Supabase client instance
 * @param {Object} apartment - Complete apartment object with all fields
 * @param {string} oldStatus - Previous status (optional, for UPDATE operations)
 * @returns {Promise<{ok: boolean, error?: string}>}
 */
export const sendActiveWebhook = async (supabase, apartment, oldStatus = null) => {
    // Get status (handle both "Status" and "status" column names)
    const newStatus = apartment.Status || apartment.status;
    
    // Only trigger if status is 'Active' and it changed
    if (newStatus !== 'Active' || (oldStatus && oldStatus === 'Active')) {
        return { ok: true, skipped: true };
    }

    try {
        // Get real estate agent info
        const agentId = apartment.real_estate_agent_id || apartment['Real Estate Agent Id'];
        const realEstateAgent = await getRealEstateAgent(supabase, agentId);

        // Get apartment tags
        const apartmentTags = apartment.tags || [];
        
        // Get matched tenants based on tags
        const matchedTenants = await getMatchedTenants(supabase, apartment.id, apartmentTags);

        // Build payload
        const payload = {
            event_type: 'apartment_status_active',
            trigger_operation: oldStatus !== null ? 'UPDATE' : 'INSERT',
            apartment: {
                ...apartment, // Include all apartment fields
                real_estate_agent: realEstateAgent
            },
            matched_tenants: matchedTenants,
            matched_tenants_count: matchedTenants.length,
            timestamp: new Date().toISOString()
        };

        console.log('[ApartmentWebhook] Sending Active webhook for apartment:', apartment.id, `(${matchedTenants.length} matched tenants)`);

        const result = await fetchWithRetry(ACTIVE_WEBHOOK_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(payload)
        });

        if (result.ok) {
            console.log('[ApartmentWebhook] ✅ Active webhook sent successfully');
            return { ok: true };
        } else {
            console.error('[ApartmentWebhook] ❌ Active webhook failed:', result.message);
            return { ok: false, error: result.message };
        }
    } catch (error) {
        console.error('[ApartmentWebhook] Error sending Active webhook:', error);
        return { ok: false, error: error.message };
    }
};

/**
 * Handle apartment status change
 * Automatically calls the appropriate webhook based on new status
 * Use this function after updating/inserting apartments
 * @param {Object} supabase - Supabase client instance
 * @param {Object} apartment - Complete apartment object (after update/insert)
 * @param {string} oldStatus - Previous status (optional, for UPDATE operations)
 * @returns {Promise<{ok: boolean, webhooks?: Array}>}
 */
export const handleApartmentStatusChange = async (supabase, apartment, oldStatus = null) => {
    const newStatus = apartment.Status || apartment.status;
    const results = [];

    // Trigger CreateLink webhook if status is CreateLink
    if (newStatus === 'CreateLink') {
        const result = await sendCreateLinkWebhook(supabase, apartment, oldStatus);
        results.push({ webhook: 'CreateLink', ...result });
    }

    // Trigger Active webhook if status is Active
    if (newStatus === 'Active') {
        const result = await sendActiveWebhook(supabase, apartment, oldStatus);
        results.push({ webhook: 'Active', ...result });
    }

    return {
        ok: results.every(r => r.ok || r.skipped),
        webhooks: results
    };
};

/**
 * Wrapper function for Supabase apartment updates
 * Use this instead of direct supabase.from('apartments').update()
 * It will automatically trigger webhooks after the update
 * @param {Object} supabase - Supabase client instance
 * @param {string} apartmentId - Apartment UUID
 * @param {Object} updates - Fields to update (must include status if changing it)
 * @returns {Promise<{ok: boolean, data?: Object, error?: string}>}
 */
export const updateApartmentWithWebhook = async (supabase, apartmentId, updates) => {
    try {
        // Get current apartment to check old status
        const { data: oldApartment, error: fetchError } = await supabase
            .from('apartments')
            .select('*')
            .eq('id', apartmentId)
            .single();

        if (fetchError) {
            return { ok: false, error: `Failed to fetch apartment: ${fetchError.message}` };
        }

        const oldStatus = oldApartment.Status || oldApartment.status;

        // Update apartment
        const { data: updatedApartment, error: updateError } = await supabase
            .from('apartments')
            .update(updates)
            .eq('id', apartmentId)
            .select()
            .single();

        if (updateError) {
            return { ok: false, error: `Failed to update apartment: ${updateError.message}` };
        }

        // Trigger webhooks if status changed
        const webhookResult = await handleApartmentStatusChange(supabase, updatedApartment, oldStatus);

        return {
            ok: true,
            data: updatedApartment,
            webhooks: webhookResult.webhooks
        };
    } catch (error) {
        console.error('[ApartmentWebhook] Error in updateApartmentWithWebhook:', error);
        return { ok: false, error: error.message };
    }
};

/**
 * Wrapper function for Supabase apartment inserts
 * Use this instead of direct supabase.from('apartments').insert()
 * It will automatically trigger webhooks after the insert
 * @param {Object} supabase - Supabase client instance
 * @param {Object} apartmentData - Apartment data to insert
 * @returns {Promise<{ok: boolean, data?: Object, error?: string}>}
 */
export const insertApartmentWithWebhook = async (supabase, apartmentData) => {
    try {
        // Insert apartment
        const { data: newApartment, error: insertError } = await supabase
            .from('apartments')
            .insert(apartmentData)
            .select()
            .single();

        if (insertError) {
            return { ok: false, error: `Failed to insert apartment: ${insertError.message}` };
        }

        // Trigger webhooks if status is CreateLink or Active
        const webhookResult = await handleApartmentStatusChange(supabase, newApartment, null);

        return {
            ok: true,
            data: newApartment,
            webhooks: webhookResult.webhooks
        };
    } catch (error) {
        console.error('[ApartmentWebhook] Error in insertApartmentWithWebhook:', error);
        return { ok: false, error: error.message };
    }
};
