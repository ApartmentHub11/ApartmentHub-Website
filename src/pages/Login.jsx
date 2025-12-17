import React, { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { Phone, ArrowLeft, CheckCircle, AlertCircle } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { translations } from '../data/translations';
import styles from './Login.module.css';

const Login = () => {
    const navigate = useNavigate();
    const location = useLocation();
    const { sendCode, login } = useAuth();
    const currentLang = useSelector((state) => state.ui.language);
    const t = translations.login[currentLang] || translations.login.nl;

    const [step, setStep] = useState('phone'); // 'phone' or 'code'
    const [phoneNumber, setPhoneNumber] = useState('');
    const [verificationCode, setVerificationCode] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState('');
    const [codeSent, setCodeSent] = useState(false);

    const handleSendCode = async (e) => {
        e.preventDefault();
        setError('');

        if (!phoneNumber || phoneNumber.length < 9) {
            setError(t.invalidPhone);
            return;
        }

        setIsLoading(true);

        try {
            const formattedPhone = phoneNumber.startsWith('+') ? phoneNumber : `+31${phoneNumber.replace(/^0/, '')}`;
            const result = await sendCode(formattedPhone);

            if (result.ok) {
                setCodeSent(true);
                setStep('code');
            } else {
                setError(result.message || t.invalidPhone);
            }
        } catch (err) {
            setError(t.invalidPhone);
        } finally {
            setIsLoading(false);
        }
    };

    const handleVerifyCode = async (e) => {
        e.preventDefault();
        setError('');

        if (!verificationCode || verificationCode.length < 4) {
            setError(t.invalidCode);
            return;
        }

        setIsLoading(true);

        try {
            const formattedPhone = phoneNumber.startsWith('+') ? phoneNumber : `+31${phoneNumber.replace(/^0/, '')}`;
            const result = await login(formattedPhone, verificationCode);

            if (result.ok) {
                const from = location.state?.from?.pathname || '/aanvraag';
                navigate(from, { replace: true });
            } else {
                setError(result.error || t.invalidCode);
            }
        } catch (err) {
            setError(t.invalidCode);
        } finally {
            setIsLoading(false);
        }
    };

    const handleBackToPhone = () => {
        setStep('phone');
        setVerificationCode('');
        setError('');
        setCodeSent(false);
    };

    const handleTestCodeClick = () => {
        setVerificationCode('123456');
    };

    return (
        <div className={styles.page}>
            <div className={styles.container}>
                <div className={styles.card}>
                    <div className={styles.iconWrapper}>
                        <Phone size={28} />
                    </div>

                    <h1 className={styles.title}>
                        {currentLang === 'en' ? 'Verification via WhatsApp' : 'Verificatie via WhatsApp'}
                    </h1>
                    <p className={styles.subtitle}>
                        {currentLang === 'en'
                            ? 'Enter your phone number to receive a verification code'
                            : 'Voer je telefoonnummer in om een verificatiecode te ontvangen'}
                    </p>

                    {step === 'phone' ? (
                        <form onSubmit={handleSendCode} className={styles.form}>
                            <div>
                                <label className={styles.inputLabel}>
                                    {currentLang === 'en' ? 'Phone number' : 'Telefoonnummer'}
                                </label>
                                <div className={styles.inputWrapper}>
                                    <input
                                        type="tel"
                                        className={styles.input}
                                        placeholder="+31 6 12345678"
                                        value={phoneNumber}
                                        onChange={(e) => setPhoneNumber(e.target.value)}
                                        required
                                    />
                                </div>
                                <p className={styles.inputHint}>
                                    {currentLang === 'en'
                                        ? 'Enter your number with country code (e.g. +31)'
                                        : 'Vul je nummer in met landcode (bijv. +31)'}
                                </p>
                            </div>

                            {error && (
                                <div className={styles.errorMessage}>
                                    <AlertCircle size={16} />
                                    {error}
                                </div>
                            )}

                            <button
                                type="submit"
                                className={styles.submitBtn}
                                disabled={isLoading}
                            >
                                {isLoading
                                    ? (currentLang === 'en' ? 'Sending...' : 'Versturen...')
                                    : (currentLang === 'en' ? 'Send verification code' : 'Stuur verificatiecode')}
                            </button>

                            <div className={styles.testModeNote}>
                                Test mode: {currentLang === 'en' ? 'Use code' : 'Gebruik code'}{' '}
                                <span className={styles.testModeCode} onClick={handleTestCodeClick}>123456</span>
                            </div>
                        </form>
                    ) : (
                        <div className={styles.form}>
                            <button
                                type="button"
                                className={styles.backButton}
                                onClick={handleBackToPhone}
                            >
                                <ArrowLeft size={16} />
                                {t.backToPhone}
                            </button>

                            {codeSent && (
                                <div className={styles.successMessage}>
                                    <CheckCircle size={16} />
                                    {t.codesSent}
                                </div>
                            )}

                            <form onSubmit={handleVerifyCode}>
                                <div style={{ marginBottom: '1rem' }}>
                                    <label className={styles.inputLabel}>
                                        {t.codeLabel}
                                    </label>
                                    <input
                                        type="text"
                                        inputMode="numeric"
                                        pattern="[0-9]*"
                                        maxLength={6}
                                        className={styles.input}
                                        placeholder={t.codePlaceholder}
                                        value={verificationCode}
                                        onChange={(e) => setVerificationCode(e.target.value.replace(/\D/g, ''))}
                                        required
                                        autoFocus
                                    />
                                </div>

                                {error && (
                                    <div className={styles.errorMessage}>
                                        <AlertCircle size={16} />
                                        {error}
                                    </div>
                                )}

                                <button
                                    type="submit"
                                    className={styles.submitBtn}
                                    disabled={isLoading}
                                >
                                    {isLoading ? t.verifying : t.verify}
                                </button>
                            </form>

                            <div className={styles.testModeNote}>
                                Test mode: {currentLang === 'en' ? 'Use code' : 'Gebruik code'}{' '}
                                <span className={styles.testModeCode} onClick={handleTestCodeClick}>123456</span>
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};

export default Login;
