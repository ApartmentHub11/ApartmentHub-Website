import React, { useState, useRef, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { CheckCircle, Home, FileText, User } from 'lucide-react';
import confetti from 'canvas-confetti';
import { useAuth } from '../contexts/AuthContext';
import { translations } from '../data/translations';
import Button from '../components/ui/Button';
import styles from './LetterOfIntent.module.css';

const LetterOfIntent = () => {
    const location = useLocation();
    const navigate = useNavigate();
    const { phoneNumber } = useAuth();
    const currentLang = useSelector((state) => state.ui.language);
    const t = translations.letterOfIntent[currentLang] || translations.letterOfIntent.nl;

    const canvasRef = useRef(null);
    const [isDrawing, setIsDrawing] = useState(false);
    const [hasSignature, setHasSignature] = useState(false);
    const [conditions, setConditions] = useState({
        condition1: false,
        condition2: false,
        condition3: false
    });
    const [submitting, setSubmitting] = useState(false);
    const [submitted, setSubmitted] = useState(false);

    const { bidAmount, startDate, motivation, conditions: rentalConditions } = location.state || {
        bidAmount: '1850',
        startDate: new Date().toISOString().split('T')[0],
        motivation: '',
        conditions: {
            huurprijs: 1850,
            adres: 'Prinsengracht 123',
            stad: 'Amsterdam'
        }
    };

    // Canvas drawing functions
    useEffect(() => {
        const canvas = canvasRef.current;
        if (!canvas) return;

        const ctx = canvas.getContext('2d');
        ctx.strokeStyle = '#111827';
        ctx.lineWidth = 2;
        ctx.lineCap = 'round';
    }, []);

    const startDrawing = (e) => {
        setIsDrawing(true);
        const canvas = canvasRef.current;
        const ctx = canvas.getContext('2d');
        const rect = canvas.getBoundingClientRect();
        const x = (e.clientX || e.touches?.[0]?.clientX) - rect.left;
        const y = (e.clientY || e.touches?.[0]?.clientY) - rect.top;
        ctx.beginPath();
        ctx.moveTo(x, y);
    };

    const draw = (e) => {
        if (!isDrawing) return;
        const canvas = canvasRef.current;
        const ctx = canvas.getContext('2d');
        const rect = canvas.getBoundingClientRect();
        const x = (e.clientX || e.touches?.[0]?.clientX) - rect.left;
        const y = (e.clientY || e.touches?.[0]?.clientY) - rect.top;
        ctx.lineTo(x, y);
        ctx.stroke();
        setHasSignature(true);
    };

    const stopDrawing = () => {
        setIsDrawing(false);
    };

    const clearSignature = () => {
        const canvas = canvasRef.current;
        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        setHasSignature(false);
    };

    const allConditionsAccepted = Object.values(conditions).every(Boolean);
    const canSubmit = allConditionsAccepted && hasSignature;

    const handleSubmit = async () => {
        if (!canSubmit) return;

        setSubmitting(true);

        // Simulate API call
        await new Promise(resolve => setTimeout(resolve, 1500));

        // Fire confetti!
        confetti({
            particleCount: 100,
            spread: 70,
            origin: { y: 0.6 }
        });

        setSubmitted(true);
        setSubmitting(false);
    };

    if (submitted) {
        return (
            <div className={styles.successPage}>
                <div className={styles.successIcon}>
                    <CheckCircle size={48} />
                </div>
                <h1 className={styles.successTitle}>{t.successTitle}</h1>
                <p className={styles.successMessage}>{t.successMessage}</p>
                <Button size="lg" onClick={() => navigate('/')}>
                    {t.backToHome}
                </Button>
            </div>
        );
    }

    return (
        <div className={styles.page}>
            <div className={styles.container}>
                <div className={styles.header}>
                    <h1 className={styles.title}>{t.title}</h1>
                    <p className={styles.subtitle}>{t.subtitle}</p>
                </div>

                <div className={styles.card}>
                    {/* Property Details */}
                    <div className={styles.section}>
                        <h2 className={styles.sectionTitle}>
                            <Home size={20} />
                            {t.propertyDetails}
                        </h2>
                        <div className={styles.detailsGrid}>
                            <div className={styles.detailItem}>
                                <span className={styles.detailLabel}>{t.address}</span>
                                <span className={styles.detailValue}>
                                    {rentalConditions?.adres || 'Prinsengracht 123, Amsterdam'}
                                </span>
                            </div>
                            <div className={styles.detailItem}>
                                <span className={styles.detailLabel}>{t.rent}</span>
                                <span className={styles.detailValue}>€{bidAmount}</span>
                            </div>
                            <div className={styles.detailItem}>
                                <span className={styles.detailLabel}>{t.startDate}</span>
                                <span className={styles.detailValue}>{startDate}</span>
                            </div>
                        </div>
                    </div>

                    {/* Tenant Details */}
                    <div className={styles.section}>
                        <h2 className={styles.sectionTitle}>
                            <User size={20} />
                            {t.tenantDetails}
                        </h2>
                        <div className={styles.detailsGrid}>
                            <div className={styles.detailItem}>
                                <span className={styles.detailLabel}>{t.phone}</span>
                                <span className={styles.detailValue}>{phoneNumber || '+31 6 xxxxxxxx'}</span>
                            </div>
                        </div>
                    </div>

                    {/* Conditions */}
                    <div className={styles.section}>
                        <h2 className={styles.sectionTitle}>
                            <FileText size={20} />
                            {t.conditions}
                        </h2>
                        <div className={styles.conditionsList}>
                            <label className={styles.conditionItem}>
                                <input
                                    type="checkbox"
                                    className={styles.checkbox}
                                    checked={conditions.condition1}
                                    onChange={(e) => setConditions(prev => ({ ...prev, condition1: e.target.checked }))}
                                />
                                <span className={styles.conditionText}>{t.condition1}</span>
                            </label>
                            <label className={styles.conditionItem}>
                                <input
                                    type="checkbox"
                                    className={styles.checkbox}
                                    checked={conditions.condition2}
                                    onChange={(e) => setConditions(prev => ({ ...prev, condition2: e.target.checked }))}
                                />
                                <span className={styles.conditionText}>{t.condition2}</span>
                            </label>
                            <label className={styles.conditionItem}>
                                <input
                                    type="checkbox"
                                    className={styles.checkbox}
                                    checked={conditions.condition3}
                                    onChange={(e) => setConditions(prev => ({ ...prev, condition3: e.target.checked }))}
                                />
                                <span className={styles.conditionText}>{t.condition3}</span>
                            </label>
                        </div>
                    </div>

                    {/* Signature */}
                    <div className={styles.section}>
                        <div className={styles.signatureSection}>
                            <div className={styles.signatureLabel}>{t.signature}</div>
                            <canvas
                                ref={canvasRef}
                                className={styles.signatureCanvas}
                                width={500}
                                height={160}
                                onMouseDown={startDrawing}
                                onMouseMove={draw}
                                onMouseUp={stopDrawing}
                                onMouseLeave={stopDrawing}
                                onTouchStart={startDrawing}
                                onTouchMove={draw}
                                onTouchEnd={stopDrawing}
                            />
                            <div className={styles.signatureActions}>
                                <Button variant="ghost" size="sm" onClick={clearSignature}>
                                    {t.clearSignature}
                                </Button>
                            </div>
                        </div>
                    </div>

                    {/* Submit */}
                    <div className={styles.submitSection}>
                        <Button
                            size="lg"
                            onClick={handleSubmit}
                            loading={submitting}
                            disabled={!canSubmit}
                            fullWidth
                        >
                            {submitting ? t.submitting : t.submit}
                        </Button>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default LetterOfIntent;
