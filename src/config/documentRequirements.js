/**
 * Document requirement configuration by work status
 */

// Document types for each work status - Tenants
export const documentsByWorkStatus = {
    student: [
        { type: 'id_bewijs', description: 'Paspoort of ID-kaart', verplicht: true },
        { type: 'inschrijfbewijs', description: 'Bewijs van inschrijving bij onderwijsinstelling', verplicht: true },
        { type: 'studiefinanciering', description: 'Bewijs van studiefinanciering of DUO', verplicht: true },
    ],
    werknemer: [
        { type: 'id_bewijs', description: 'Paspoort of ID-kaart', verplicht: true },
        { type: 'arbeidscontract', description: 'Arbeidscontract (minimaal 1 jaar vast of onbepaalde tijd)', verplicht: true },
        { type: 'loonstroken', description: 'Laatste 3 loonstroken', verplicht: true, multiFile: true, minFiles: 3, maxFiles: 3 },
        { type: 'werkgeversverklaring', description: 'Werkgeversverklaring (niet ouder dan 3 maanden)', verplicht: true },
    ],
    ondernemer: [
        { type: 'id_bewijs', description: 'Paspoort of ID-kaart', verplicht: true },
        { type: 'kvk_uittreksel', description: 'KvK uittreksel (niet ouder dan 3 maanden)', verplicht: true },
        { type: 'jaarrekening', description: 'Jaarrekening of belastingaangifte laatste 2 jaar', verplicht: true },
        { type: 'accountantsverklaring', description: 'Accountantsverklaring of IB60 formulier', verplicht: false },
    ],
    pensioen: [
        { type: 'id_bewijs', description: 'Paspoort of ID-kaart', verplicht: true },
        { type: 'pensioen_bewijs', description: 'Bewijs van pensioeninkomen', verplicht: true },
        { type: 'bankafschrift', description: 'Bankafschrift met pensioenstorting', verplicht: true },
    ]
};

// Tenant-only optional documents
export const tenantOnlyDocuments = [
    { type: 'referentie', description: 'Referentie van vorige verhuurder', verplicht: false },
    { type: 'bankafschrift_huur', description: 'Bankafschrift met laatste huurbetalingen', verplicht: false },
];

// Work status labels
export const workStatusLabels = {
    nl: {
        student: 'Student',
        werknemer: 'Werknemer',
        ondernemer: 'Ondernemer',
        pensioen: 'Gepensioneerd'
    },
    en: {
        student: 'Student',
        werknemer: 'Employee',
        ondernemer: 'Entrepreneur',
        pensioen: 'Retired'
    }
};

// Document type translations
export const documentTypeLabels = {
    nl: {
        id_bewijs: { name: 'ID-bewijs', description: 'Paspoort of ID-kaart' },
        inschrijfbewijs: { name: 'Inschrijfbewijs', description: 'Bewijs van inschrijving bij onderwijsinstelling' },
        studiefinanciering: { name: 'Studiefinanciering', description: 'Bewijs van studiefinanciering of DUO' },
        arbeidscontract: { name: 'Arbeidscontract', description: 'Arbeidscontract (minimaal 1 jaar vast of onbepaalde tijd)' },
        loonstroken: { name: 'Loonstroken', description: 'Laatste 3 loonstroken' },
        werkgeversverklaring: { name: 'Werkgeversverklaring', description: 'Werkgeversverklaring (niet ouder dan 3 maanden)' },
        kvk_uittreksel: { name: 'KvK uittreksel', description: 'KvK uittreksel (niet ouder dan 3 maanden)' },
        jaarrekening: { name: 'Jaarrekening', description: 'Jaarrekening of belastingaangifte laatste 2 jaar' },
        accountantsverklaring: { name: 'Accountantsverklaring', description: 'Accountantsverklaring of IB60 formulier' },
        pensioen_bewijs: { name: 'Pensioenbewijs', description: 'Bewijs van pensioeninkomen' },
        bankafschrift: { name: 'Bankafschrift', description: 'Bankafschrift met pensioenstorting' },
        referentie: { name: 'Referentie', description: 'Referentie van vorige verhuurder' },
        bankafschrift_huur: { name: 'Bankafschrift huur', description: 'Bankafschrift met laatste huurbetalingen' },
    },
    en: {
        id_bewijs: { name: 'ID Document', description: 'Passport or ID card' },
        inschrijfbewijs: { name: 'Enrollment Proof', description: 'Proof of enrollment at educational institution' },
        studiefinanciering: { name: 'Student Finance', description: 'Proof of student financing or DUO' },
        arbeidscontract: { name: 'Employment Contract', description: 'Employment contract (minimum 1 year or permanent)' },
        loonstroken: { name: 'Payslips', description: 'Last 3 payslips' },
        werkgeversverklaring: { name: 'Employer Statement', description: 'Employer statement (not older than 3 months)' },
        kvk_uittreksel: { name: 'Chamber of Commerce', description: 'Chamber of Commerce extract (not older than 3 months)' },
        jaarrekening: { name: 'Annual Statement', description: 'Annual statement or tax return for last 2 years' },
        accountantsverklaring: { name: 'Accountant Statement', description: 'Accountant statement or IB60 form' },
        pensioen_bewijs: { name: 'Pension Proof', description: 'Proof of pension income' },
        bankafschrift: { name: 'Bank Statement', description: 'Bank statement with pension deposit' },
        referentie: { name: 'Reference', description: 'Reference from previous landlord' },
        bankafschrift_huur: { name: 'Rent Bank Statement', description: 'Bank statement with last rental payments' },
    }
};
