/**
 * Document status API service
 * Mock implementation for development
 */

// Mock rental conditions data
const mockRentalConditions = {
    huurprijs: 1850,
    waarborgsom: 3700,
    servicekosten: 150,
    beschikbaar: '1 januari 2025',
    minBod: 1850,
    adres: 'Prinsengracht 123',
    stad: 'Amsterdam',
    oppervlakte: 65,
    kamers: 2,
    type: 'Appartement',
};

// Mock persons data
const mockPersonen = [
    {
        persoonId: 'person-1',
        naam: 'Jan de Vries',
        rol: 'Hoofdhuurder',
        whatsapp: '+31612345678',
        docsCompleet: false,
        documenten: []
    }
];

/**
 * Get document status for a dossier
 * @param {string} token - Auth token
 * @returns {Promise<Object>}
 */
export const getDocumentStatus = async (token) => {
    // Simulate API delay
    await new Promise(resolve => setTimeout(resolve, 500));

    return {
        ok: true,
        dossierId: 'dossier-123',
        status: 'in_behandeling',
        voortgang: 25,
        huurvoorwaarden: mockRentalConditions,
        personen: mockPersonen,
        redenOnvolledig: null
    };
};

/**
 * Upload documents for a person
 * @param {string} token - Auth token
 * @param {string} persoonId - Person ID
 * @param {Object} files - Files to upload { documentType: File }
 * @returns {Promise<Object>}
 */
export const uploadDocuments = async (token, persoonId, files) => {
    // Simulate API delay
    await new Promise(resolve => setTimeout(resolve, 1000));

    console.log('[Mock] Uploading documents for person:', persoonId, files);

    return {
        ok: true,
        message: 'Documents uploaded successfully'
    };
};

/**
 * Send WhatsApp reminder to a person
 * @param {string} token - Auth token
 * @param {string} persoonId - Person ID
 * @returns {Promise<Object>}
 */
export const sendReminder = async (token, persoonId) => {
    await new Promise(resolve => setTimeout(resolve, 500));

    console.log('[Mock] Sending reminder to person:', persoonId);

    return {
        ok: true,
        message: 'Reminder sent successfully'
    };
};

/**
 * Set reason for incomplete documents
 * @param {string} token - Auth token
 * @param {string} reason - Reason text
 * @returns {Promise<Object>}
 */
export const setRedenOnvolledig = async (token, reason) => {
    await new Promise(resolve => setTimeout(resolve, 500));

    console.log('[Mock] Setting reason for incomplete:', reason);

    return {
        ok: true,
        message: 'Reason saved successfully'
    };
};

/**
 * Add a person (co-tenant or guarantor) to the dossier
 * @param {string} token - Auth token
 * @param {string} rol - Role ('Medehuurder' or 'Garantsteller')
 * @param {string} naam - Name
 * @param {string} whatsapp - WhatsApp number
 * @param {string} linkedToPersoonId - ID of the person this is linked to
 * @returns {Promise<Object>}
 */
export const addPerson = async (token, rol, naam, whatsapp, linkedToPersoonId = null) => {
    await new Promise(resolve => setTimeout(resolve, 800));

    console.log('[Mock] Adding person:', { rol, naam, whatsapp, linkedToPersoonId });

    const newPerson = {
        persoonId: 'person-' + Date.now(),
        naam,
        rol,
        whatsapp,
        docsCompleet: false,
        documenten: [],
        linkedTo: linkedToPersoonId
    };

    return {
        ok: true,
        person: newPerson,
        message: `${rol} added successfully`
    };
};

/**
 * Remove a person from the dossier
 * @param {string} token - Auth token
 * @param {string} persoonId - Person ID to remove
 * @returns {Promise<Object>}
 */
export const removePerson = async (token, persoonId) => {
    await new Promise(resolve => setTimeout(resolve, 500));

    console.log('[Mock] Removing person:', persoonId);

    return {
        ok: true,
        message: 'Person removed successfully'
    };
};

/**
 * Submit the complete application
 * @param {string} token - Auth token
 * @param {Object} applicationData - Complete application data
 * @returns {Promise<Object>}
 */
export const submitApplication = async (token, applicationData) => {
    await new Promise(resolve => setTimeout(resolve, 1500));

    console.log('[Mock] Submitting application:', applicationData);

    return {
        ok: true,
        message: 'Application submitted successfully',
        applicationId: 'app-' + Date.now()
    };
};
