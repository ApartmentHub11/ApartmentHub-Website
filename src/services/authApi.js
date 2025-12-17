import { supabase } from '../integrations/supabase/client';

/**
 * Send WhatsApp verification code to phone number
 * @param {string} phoneNumber - Phone number with country code
 * @returns {Promise<{ok: boolean, message?: string}>}
 */
export const sendWhatsAppCode = async (phoneNumber) => {
    try {
        // For development, simulate success
        if (!supabase) {
            console.log('[Mock] Sending code to:', phoneNumber);
            return { ok: true, message: 'Code sent successfully (mock)' };
        }

        const { data, error } = await supabase.functions.invoke('auth-send-code', {
            body: { phone_number: phoneNumber }
        });

        if (error) {
            console.error('Error sending code:', error);
            return { ok: false, message: error.message };
        }

        return { ok: true, message: data?.message || 'Code sent successfully' };
    } catch (error) {
        console.error('Error sending WhatsApp code:', error);
        return { ok: false, message: 'Failed to send verification code' };
    }
};

/**
 * Verify WhatsApp code and get auth token
 * @param {string} phoneNumber - Phone number with country code
 * @param {string} code - Verification code
 * @returns {Promise<{ok: boolean, token?: string, dossier_id?: string, reason?: string}>}
 */
export const verifyWhatsAppCode = async (phoneNumber, code) => {
    try {
        // For development, accept code "123456"
        if (!supabase || code === '123456') {
            console.log('[Mock] Verifying code for:', phoneNumber);
            return {
                ok: true,
                token: 'mock-auth-token-' + Date.now(),
                dossier_id: 'mock-dossier-' + Date.now()
            };
        }

        const { data, error } = await supabase.functions.invoke('auth-verify-code', {
            body: { phone_number: phoneNumber, code }
        });

        if (error) {
            console.error('Error verifying code:', error);
            return { ok: false, reason: error.message };
        }

        if (!data?.ok) {
            return { ok: false, reason: data?.reason || 'Invalid code' };
        }

        return {
            ok: true,
            token: data.token,
            dossier_id: data.dossier_id
        };
    } catch (error) {
        console.error('Error verifying code:', error);
        return { ok: false, reason: 'Verification failed' };
    }
};
