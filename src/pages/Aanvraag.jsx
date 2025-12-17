import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import {
    LogOut, FileText, Euro, Calendar, Plus, ChevronDown,
    AlertCircle, MessageCircle, Send, Clock, HelpCircle
} from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { translations } from '../data/translations';
import { getDocumentStatus } from '../services/documentenApi';
import WorkStatusSelector from '../components/aanvraag/WorkStatusSelector';
import RentalFAQ from '../components/aanvraag/RentalFAQ';
import InlineDocumentUpload from '../components/aanvraag/InlineDocumentUpload';
import MultiFileDocumentUpload from '../components/aanvraag/MultiFileDocumentUpload';
import {
    documentsByWorkStatus,
    tenantOnlyDocuments,
    documentTypeLabels
} from '../config/documentRequirements';
import styles from './Aanvraag.module.css';

const Aanvraag = () => {
    const navigate = useNavigate();
    const { token, logout, phoneNumber } = useAuth();
    const currentLang = useSelector((state) => state.ui.language);
    const t = translations.aanvraag[currentLang] || translations.aanvraag.nl;

    const [loading, setLoading] = useState(true);
    const [submitting, setSubmitting] = useState(false);
    const [expandedTenant, setExpandedTenant] = useState(true);

    // Form state
    const [bidAmount, setBidAmount] = useState('2100');
    const [startDate, setStartDate] = useState('');
    const [monthsAdvance, setMonthsAdvance] = useState('0');
    const [motivation, setMotivation] = useState('');

    // Tenant form
    const [fullName, setFullName] = useState('Jan Jansen');
    const [email, setEmail] = useState('');
    const [workStatus, setWorkStatus] = useState('');
    const [currentAddress, setCurrentAddress] = useState('');
    const [postcode, setPostcode] = useState('');
    const [currentCity, setCurrentCity] = useState('');
    const [grossIncome, setGrossIncome] = useState('');
    const [uploadedDocuments, setUploadedDocuments] = useState({});

    // Handle single file upload
    const handleFileUpload = (docType, file) => {
        setUploadedDocuments(prev => ({
            ...prev,
            [docType]: file
        }));
    };

    // Handle multi file upload
    const handleMultiFileUpload = (docType, files) => {
        setUploadedDocuments(prev => ({
            ...prev,
            [docType]: files
        }));
    };

    // Handle file removal
    const handleRemoveFile = (docType, index = null) => {
        setUploadedDocuments(prev => {
            if (index === null) {
                // Single file removal
                const newState = { ...prev };
                delete newState[docType];
                return newState;
            } else {
                // Multi file removal
                const currentFiles = prev[docType] || [];
                const newFiles = currentFiles.filter((_, i) => i !== index);
                return {
                    ...prev,
                    [docType]: newFiles
                };
            }
        });
    };

    const conditions = {
        huurprijs: 2100,
        waarborgsom: 4200,
        servicekosten: 'G/W/E exclusief',
        beschikbaar: '01-03-2025'
    };

    // Check if all required fields are filled
    const isFormValid = bidAmount && startDate && fullName && email && workStatus && grossIncome;

    const progress = isFormValid ? 100 : 0;

    useEffect(() => {
        // Simulate loading
        const timer = setTimeout(() => setLoading(false), 500);
        return () => clearTimeout(timer);
    }, []);

    const handleLogout = () => {
        logout();
        navigate('/login');
    };

    const handleSubmit = async () => {
        setSubmitting(true);
        await new Promise(resolve => setTimeout(resolve, 1500));
        navigate('/letter-of-intent', {
            state: { bidAmount, startDate, motivation, conditions }
        });
    };

    if (loading) {
        return (
            <div className={styles.page}>
                <div className={styles.container} style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '50vh' }}>
                    Loading...
                </div>
            </div>
        );
    }

    return (
        <div className={styles.page}>
            {/* Header */}
            <div className={styles.header}>
                <div className={styles.headerContainer}>
                    <div className={styles.headerLeft}>
                        <span className={styles.propertyLink}>📍 Centrurbaan 123, Amsterdam</span>
                    </div>
                    <div className={styles.headerButtons}>
                        <button className={styles.headerBtn}>
                            {currentLang === 'en' ? 'Choose another apartment' : 'Ander appartement kiezen'}
                        </button>
                        <button className={styles.headerBtn} onClick={handleLogout}>
                            <LogOut size={16} />
                            {currentLang === 'en' ? 'Log out' : 'Uitloggen'}
                        </button>
                    </div>
                </div>
            </div>

            <div className={styles.container}>
                <h1 className={styles.pageTitle}>
                    {currentLang === 'en' ? 'Rental Application' : 'Huurapplicatie'}
                </h1>

                {/* Progress */}
                <div className={styles.progressSection}>
                    <div className={styles.progressTop}>
                        <span className={styles.progressLabel}>
                            {currentLang === 'en' ? 'Progress' : 'Voortgang'}
                        </span>
                        <span className={styles.progressValue}>{progress}%</span>
                    </div>
                    <div className={styles.progressBar}>
                        <div className={styles.progressFill} style={{ width: `${progress}%` }} />
                    </div>
                </div>

                <div className={styles.mainLayout}>
                    {/* Sidebar */}
                    <div className={styles.sidebar}>
                        {/* Rental Conditions */}
                        <div className={styles.sidebarCard}>
                            <div className={styles.sidebarHeader}>
                                <FileText size={18} />
                                <h3 className={styles.sidebarTitle}>
                                    {currentLang === 'en' ? 'Rental Conditions' : 'Huurvoorwaarden'}
                                </h3>
                            </div>
                            <div className={styles.sidebarContent}>
                                <div className={styles.priceSection}>
                                    <div className={styles.priceIcon}>
                                        <Euro size={24} />
                                    </div>
                                    <div className={styles.priceDetails}>
                                        <p className={styles.priceLabel}>
                                            {currentLang === 'en' ? 'Minimum rent price' : 'Minimale huurprijs'}
                                        </p>
                                        <p className={styles.priceValue}>€{conditions.huurprijs}</p>
                                        <p className={styles.priceUnit}>
                                            {currentLang === 'en' ? 'per month' : 'per maand'}
                                        </p>
                                    </div>
                                </div>

                                <div className={styles.detailRow}>
                                    <span className={styles.detailLabel}>
                                        <Euro size={14} />
                                        {currentLang === 'en' ? 'Deposit' : 'Waarborgsom'}
                                    </span>
                                    <span className={styles.detailValue}>€{conditions.waarborgsom}</span>
                                </div>
                                <div className={styles.detailRow}>
                                    <span className={styles.detailLabel}>
                                        {currentLang === 'en' ? 'Service costs' : 'Servicekosten'}
                                    </span>
                                    <span className={styles.detailValue}>{conditions.servicekosten}</span>
                                </div>
                                <div className={styles.detailRow}>
                                    <span className={styles.detailLabel}>
                                        <Calendar size={14} />
                                        {currentLang === 'en' ? 'Available from' : 'Beschikbaar voor'}
                                    </span>
                                    <span className={styles.detailValue}>{conditions.beschikbaar}</span>
                                </div>
                            </div>
                        </div>

                        {/* FAQ */}
                        <div className={styles.faqCard}>
                            <div className={styles.faqHeader}>
                                <HelpCircle size={18} />
                                {currentLang === 'en' ? 'Frequently asked questions' : 'Veelgestelde vragen'}
                            </div>
                            <RentalFAQ lang={currentLang} />
                        </div>
                    </div>

                    {/* Main Content */}
                    <div className={styles.content}>
                        {/* Bid Section */}
                        <div className={styles.sectionHeader}>
                            <span className={styles.sectionNumber}>1</span>
                            <h2 className={styles.sectionTitle}>
                                {currentLang === 'en' ? 'Your bid' : 'Jouw bod'}
                            </h2>
                        </div>
                        <div className={styles.bidCard}>
                            <div className={styles.bidCardHeader}>
                                <h3 className={styles.bidCardTitle}>
                                    <span>💰</span>
                                    <span>{currentLang === 'en' ? 'Place your bid' : 'Plaats jouw bod'}</span>
                                </h3>
                            </div>
                            <div className={styles.bidCardContent}>
                                <div className={styles.bidGrid}>
                                    <div className={styles.inputGroup}>
                                        <label className={styles.inputLabel}>
                                            💶 {currentLang === 'en' ? 'Bid per month' : 'Bod per maand'}
                                            <span className={styles.required}>*</span>
                                        </label>
                                        <div className={styles.inputWrapper}>
                                            <span className={styles.currencyPrefix}>€</span>
                                            <input
                                                type="number"
                                                className={`${styles.input} ${styles.inputWithPrefix} ${styles.bidInput}`}
                                                value={bidAmount}
                                                onChange={(e) => setBidAmount(e.target.value)}
                                                placeholder="2100"
                                            />
                                        </div>
                                        <span className={styles.inputHint}>
                                            {currentLang === 'en'
                                                ? 'The higher, the more attractive to the owner.'
                                                : 'Hoe hoger, hoe aantrekkelijker voor de eigenaar.'}
                                        </span>
                                    </div>

                                    <div className={styles.inputGroup}>
                                        <label className={styles.inputLabel}>
                                            {currentLang === 'en' ? 'Desired start date' : 'Gewenste startdatum'}
                                            <span className={styles.required}>*</span>
                                        </label>
                                        <div className={styles.inputWrapper}>
                                            <Calendar size={16} className={styles.inputIcon} />
                                            <input
                                                type="date"
                                                className={`${styles.input} ${styles.inputWithIcon}`}
                                                value={startDate}
                                                onChange={(e) => setStartDate(e.target.value)}
                                            />
                                        </div>
                                        <span className={styles.inputHint}>
                                            {currentLang === 'en'
                                                ? `Earliest possible: ${conditions.beschikbaar}. Later = more attractive.`
                                                : `Vroegst mogelijk: ${conditions.beschikbaar}. Later = minder aantrekkelijk.`}
                                        </span>
                                    </div>
                                </div>

                                <div className={styles.inputGroup} style={{ marginTop: '1.5rem' }}>
                                    <label className={styles.inputLabel}>
                                        {currentLang === 'en' ? 'Months rent in advance' : 'Maanden huur vooruit betalen'}
                                    </label>
                                    <select
                                        className={styles.select}
                                        value={monthsAdvance}
                                        onChange={(e) => setMonthsAdvance(e.target.value)}
                                    >
                                        <option value="0">0 {currentLang === 'en' ? 'months' : 'maanden'}</option>
                                        <option value="1">1 {currentLang === 'en' ? 'month' : 'maand'}</option>
                                        <option value="2">2 {currentLang === 'en' ? 'months' : 'maanden'}</option>
                                        <option value="3">3 {currentLang === 'en' ? 'months' : 'maanden'}</option>
                                        <option value="6">6 {currentLang === 'en' ? 'months' : 'maanden'}</option>
                                        <option value="12">12 {currentLang === 'en' ? 'months' : 'maanden'}</option>
                                    </select>
                                    <span className={styles.inputHint}>
                                        {currentLang === 'en'
                                            ? 'The more in advance, the more attractive.'
                                            : 'Hoe meer vooruit, hoe aantrekkelijker.'}
                                    </span>
                                </div>

                                <div className={styles.inputGroup} style={{ marginTop: '1.5rem' }}>
                                    <label className={styles.inputLabel}>
                                        {currentLang === 'en' ? 'Motivation (optional)' : 'Motivatie (optioneel)'}
                                    </label>
                                    <textarea
                                        className={styles.textarea}
                                        value={motivation}
                                        onChange={(e) => setMotivation(e.target.value)}
                                        placeholder={currentLang === 'en'
                                            ? 'Why do you want to live here? What makes you a suitable tenant?'
                                            : 'Waarom wil je hier wonen? Wat maakt jou een geschikte huurder?'}
                                        maxLength={500}
                                    />
                                    <div className={styles.charCount}>
                                        {motivation.length}/500 {currentLang === 'en' ? 'characters' : 'karakters'}
                                    </div>
                                </div>
                            </div>
                        </div>

                        {/* Tenant Details Section */}
                        <div className={styles.sectionHeader}>
                            <span className={styles.sectionNumber}>2</span>
                            <h2 className={styles.sectionTitle}>
                                {currentLang === 'en' ? 'Your details' : 'Jouw gegevens'}
                            </h2>
                        </div>
                        <div className={styles.detailsCard}>
                            {/* Main Tenant Card */}
                            <div className={styles.tenantCard}>
                                <div
                                    className={styles.tenantHeader}
                                    onClick={() => setExpandedTenant(!expandedTenant)}
                                >
                                    <div className={styles.tenantInfo}>
                                        <div className={styles.tenantAvatar}>👤</div>
                                        <div className={styles.tenantDetails}>
                                            <span className={styles.tenantRole}>
                                                {currentLang === 'en' ? 'MAIN TENANT' : 'HOOFDHUURDER'}
                                            </span>
                                            <span className={styles.tenantName}>{fullName || 'Jan Jansen'}</span>
                                        </div>
                                    </div>
                                    <div className={styles.tenantRight}>
                                        <div className={styles.docStatus}>
                                            <span className={styles.docStatusLabel}>
                                                {currentLang === 'en' ? 'Documents' : 'Documenten'}
                                            </span>
                                            <span className={`${styles.docStatusBadge} ${styles.badgeMissing}`}>
                                                0% 🔴 {currentLang === 'en' ? 'Missing' : 'Ontbreekt'}
                                            </span>
                                        </div>
                                        <ChevronDown
                                            size={20}
                                            className={`${styles.expandIcon} ${expandedTenant ? styles.expandIconOpen : ''}`}
                                        />
                                    </div>
                                </div>

                                {expandedTenant && (
                                    <div className={styles.tenantBody}>
                                        <div className={styles.formGrid}>
                                            <div className={styles.inputGroup}>
                                                <label className={styles.inputLabel}>
                                                    {currentLang === 'en' ? 'Full name' : 'Volledige naam'}
                                                    <span className={styles.required}>*</span>
                                                </label>
                                                <input
                                                    type="text"
                                                    className={styles.input}
                                                    value={fullName}
                                                    onChange={(e) => setFullName(e.target.value)}
                                                    placeholder="Jan Jansen"
                                                />
                                            </div>

                                            <div className={styles.inputGroup}>
                                                <label className={styles.inputLabel}>
                                                    {currentLang === 'en' ? 'Email address' : 'E-mailadres'}
                                                    <span className={styles.required}>*</span>
                                                </label>
                                                <input
                                                    type="email"
                                                    className={styles.input}
                                                    value={email}
                                                    onChange={(e) => setEmail(e.target.value)}
                                                    placeholder="jan@voorbeeld.nl"
                                                />
                                            </div>

                                            <div className={`${styles.inputGroup} ${styles.formGridFull}`}>
                                                <label className={styles.inputLabel}>
                                                    💼 {currentLang === 'en' ? 'Work status' : 'Werk situatie'}
                                                    <span className={styles.required}>*</span>
                                                </label>
                                                <div className={styles.workStatusSection}>
                                                    <WorkStatusSelector
                                                        value={workStatus}
                                                        onChange={setWorkStatus}
                                                        lang={currentLang}
                                                    />
                                                </div>
                                            </div>

                                            <div className={styles.inputGroup}>
                                                <label className={styles.inputLabel}>
                                                    {currentLang === 'en' ? 'Current address' : 'Huidige adres'}
                                                </label>
                                                <input
                                                    type="text"
                                                    className={styles.input}
                                                    value={currentAddress}
                                                    onChange={(e) => setCurrentAddress(e.target.value)}
                                                    placeholder="Straatnaam 123"
                                                />
                                            </div>

                                            <div className={styles.inputGroup}>
                                                <label className={styles.inputLabel}>
                                                    {currentLang === 'en' ? 'Postcode' : 'Postcode'}
                                                </label>
                                                <input
                                                    type="text"
                                                    className={styles.input}
                                                    value={postcode}
                                                    onChange={(e) => setPostcode(e.target.value)}
                                                    placeholder="1234 AB"
                                                />
                                            </div>

                                            <div className={styles.inputGroup}>
                                                <label className={styles.inputLabel}>
                                                    {currentLang === 'en' ? 'Current city' : 'Huidige woonplaats'}
                                                </label>
                                                <input
                                                    type="text"
                                                    className={styles.input}
                                                    value={currentCity}
                                                    onChange={(e) => setCurrentCity(e.target.value)}
                                                    placeholder="Amsterdam"
                                                />
                                            </div>

                                            <div className={styles.inputGroup}>
                                                <label className={styles.inputLabel}>
                                                    {currentLang === 'en' ? 'Gross annual income' : 'Bruto jaarinkomen'}
                                                    <span className={styles.required}>*</span>
                                                </label>
                                                <div className={styles.inputWrapper}>
                                                    <span className={styles.currencyPrefix}>€</span>
                                                    <input
                                                        type="number"
                                                        className={`${styles.input} ${styles.inputWithPrefix}`}
                                                        value={grossIncome}
                                                        onChange={(e) => setGrossIncome(e.target.value)}
                                                        placeholder="45000"
                                                    />
                                                </div>
                                            </div>
                                        </div>

                                        {/* Required Documents */}
                                        <div className={styles.documentsSection}>
                                            <h4 className={styles.documentsTitle}>
                                                📎 {currentLang === 'en' ? 'Required documents' : 'Benodigde documenten'}
                                            </h4>

                                            {!workStatus ? (
                                                <div className={styles.documentsNote}>
                                                    <AlertCircle size={16} />
                                                    {currentLang === 'en'
                                                        ? 'Select your work status first to see which documents are required.'
                                                        : 'Selecteer eerst je werk situatie om te zien welke documenten nodig zijn.'}
                                                </div>
                                            ) : (
                                                <div className={styles.uploadStack}>
                                                    {(documentsByWorkStatus[workStatus] || []).map((doc) => {
                                                        const docLabel = documentTypeLabels[currentLang]?.[doc.type]?.name || doc.type;
                                                        const docDesc = documentTypeLabels[currentLang]?.[doc.type]?.description || doc.description;
                                                        const uploaded = uploadedDocuments[doc.type];

                                                        if (doc.multiFile) {
                                                            return (
                                                                <MultiFileDocumentUpload
                                                                    key={doc.type}
                                                                    documentType={docLabel}
                                                                    description={docDesc}
                                                                    verplicht={doc.verplicht}
                                                                    maxFiles={doc.maxFiles}
                                                                    minFiles={doc.minFiles}
                                                                    uploadedFiles={Array.isArray(uploaded) ? uploaded : []}
                                                                    onUpload={(files) => handleMultiFileUpload(doc.type, files)}
                                                                    onRemove={(index) => handleRemoveFile(doc.type, index)}
                                                                    lang={currentLang}
                                                                />
                                                            );
                                                        }

                                                        return (
                                                            <InlineDocumentUpload
                                                                key={doc.type}
                                                                documentType={docLabel}
                                                                description={docDesc}
                                                                verplicht={doc.verplicht}
                                                                status={uploaded ? 'ontvangen' : 'ontbreekt'}
                                                                fileName={uploaded?.name}
                                                                onUpload={(file) => handleFileUpload(doc.type, file)}
                                                                onRemove={() => handleRemoveFile(doc.type)}
                                                                lang={currentLang}
                                                            />
                                                        );
                                                    })}

                                                    {/* Tenant Only Documents (Optional) */}
                                                    {tenantOnlyDocuments.map((doc) => {
                                                        const docLabel = documentTypeLabels[currentLang]?.[doc.type]?.name || doc.type;
                                                        const docDesc = documentTypeLabels[currentLang]?.[doc.type]?.description || doc.description;
                                                        const uploaded = uploadedDocuments[doc.type];

                                                        return (
                                                            <InlineDocumentUpload
                                                                key={doc.type}
                                                                documentType={docLabel}
                                                                description={docDesc}
                                                                verplicht={doc.verplicht}
                                                                status={uploaded ? 'ontvangen' : 'ontbreekt'}
                                                                fileName={uploaded?.name}
                                                                onUpload={(file) => handleFileUpload(doc.type, file)}
                                                                onRemove={() => handleRemoveFile(doc.type)}
                                                                lang={currentLang}
                                                            />
                                                        );
                                                    })}
                                                </div>
                                            )}
                                        </div>

                                        <button
                                            className={styles.collapseBtn}
                                            onClick={() => setExpandedTenant(false)}
                                        >
                                            <ChevronDown size={16} />
                                            {currentLang === 'en' ? 'Collapse' : 'Inklappen'}
                                        </button>
                                    </div>
                                )}
                            </div>

                            {/* Add guarantor link */}
                            <button className={styles.addPersonLink}>
                                <Plus size={16} />
                                {currentLang === 'en'
                                    ? `Add guarantor for ${fullName || 'Jan Jansen'}`
                                    : `Voeg garantsteller toe voor ${fullName || 'Jan Jansen'}`}
                            </button>

                            {/* Add co-tenant button */}
                            <button className={styles.addCoTenantBtn}>
                                <Plus size={16} />
                                {currentLang === 'en' ? 'Add co-tenant' : 'Voeg medehuurder toe'}
                            </button>

                            {/* Submit Button */}
                            <button
                                className={`${styles.submitBtn} ${!isFormValid ? styles.submitBtnDisabled : ''}`}
                                onClick={handleSubmit}
                                disabled={submitting || !isFormValid}
                            >
                                {submitting ? '...' : '✓'}
                                {submitting
                                    ? (currentLang === 'en' ? 'Submitting...' : 'Indienen...')
                                    : (currentLang === 'en' ? 'Submit Application' : 'Aanvraag Indienen')}
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Aanvraag;
