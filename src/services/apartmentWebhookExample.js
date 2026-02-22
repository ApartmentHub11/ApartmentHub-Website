/**
 * Example usage of apartment webhook service
 * This shows how to use the webhook functions in your code
 */

import { supabase } from '../integrations/supabase/client';
import { 
    updateApartmentWithWebhook, 
    insertApartmentWithWebhook,
    handleApartmentStatusChange,
    sendCreateLinkWebhook,
    sendActiveWebhook
} from './apartmentWebhookService';

/**
 * Example 1: Update apartment status (recommended - handles webhooks automatically)
 */
export const updateApartmentStatusExample = async (apartmentId, newStatus) => {
    const result = await updateApartmentWithWebhook(
        supabase,
        apartmentId,
        { status: newStatus } // or { Status: newStatus } depending on your column name
    );

    if (result.ok) {
        console.log('Apartment updated:', result.data);
        console.log('Webhooks triggered:', result.webhooks);
    } else {
        console.error('Error:', result.error);
    }

    return result;
};

/**
 * Example 2: Insert new apartment (recommended - handles webhooks automatically)
 */
export const createApartmentExample = async (apartmentData) => {
    const result = await insertApartmentWithWebhook(
        supabase,
        {
            "Full Address": apartmentData.fullAddress,
            status: apartmentData.status, // or Status: apartmentData.status
            tags: apartmentData.tags || [],
            rental_price: apartmentData.rentalPrice,
            bedrooms: apartmentData.bedrooms,
            // ... other fields
        }
    );

    if (result.ok) {
        console.log('Apartment created:', result.data);
        console.log('Webhooks triggered:', result.webhooks);
    } else {
        console.error('Error:', result.error);
    }

    return result;
};

/**
 * Example 3: Manual webhook trigger after custom update
 * Use this if you need to update apartment manually and then trigger webhooks
 */
export const updateApartmentManuallyExample = async (apartmentId, updates) => {
    // Update apartment manually
    const { data: updatedApartment, error } = await supabase
        .from('apartments')
        .update(updates)
        .eq('id', apartmentId)
        .select()
        .single();

    if (error) {
        return { ok: false, error: error.message };
    }

    // Get old apartment to compare status
    const { data: oldApartment } = await supabase
        .from('apartments')
        .select('status, Status')
        .eq('id', apartmentId)
        .single();

    const oldStatus = oldApartment?.Status || oldApartment?.status;

    // Manually trigger webhooks
    const webhookResult = await handleApartmentStatusChange(
        supabase,
        updatedApartment,
        oldStatus
    );

    return {
        ok: true,
        data: updatedApartment,
        webhooks: webhookResult.webhooks
    };
};

/**
 * Example 4: Trigger specific webhook directly
 */
export const triggerCreateLinkWebhookExample = async (apartmentId) => {
    // Fetch apartment
    const { data: apartment, error } = await supabase
        .from('apartments')
        .select('*')
        .eq('id', apartmentId)
        .single();

    if (error || !apartment) {
        return { ok: false, error: 'Apartment not found' };
    }

    // Trigger CreateLink webhook
    const result = await sendCreateLinkWebhook(supabase, apartment);
    return result;
};

/**
 * Example 5: Trigger Active webhook directly
 */
export const triggerActiveWebhookExample = async (apartmentId) => {
    // Fetch apartment
    const { data: apartment, error } = await supabase
        .from('apartments')
        .select('*')
        .eq('id', apartmentId)
        .single();

    if (error || !apartment) {
        return { ok: false, error: 'Apartment not found' };
    }

    // Trigger Active webhook
    const result = await sendActiveWebhook(supabase, apartment);
    return result;
};
