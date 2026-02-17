'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useSelector } from 'react-redux';
import { translations } from '../data/translations';
import Button from '../components/ui/Button';
import styles from './AppartementenSelectie.module.css';

// Mock apartments data
const apartments = [
    {
        id: 'apt-1',
        address: 'Prinsengracht 123',
        city: 'Amsterdam',
        price: 1850,
        rooms: 2,
        surface: 65,
    },
    {
        id: 'apt-2',
        address: 'Herengracht 456',
        city: 'Amsterdam',
        price: 2200,
        rooms: 3,
        surface: 85,
    },
    {
        id: 'apt-3',
        address: 'Keizersgracht 789',
        city: 'Amsterdam',
        price: 1650,
        rooms: 2,
        surface: 55,
    },
    {
        id: 'apt-4',
        address: 'Vondelstraat 12',
        city: 'Amsterdam',
        price: 2500,
        rooms: 4,
        surface: 110,
    },
];

const AppartementenSelectie = () => {
    const router = useRouter();
    const currentLang = useSelector((state) => state.ui.language);
    const t = translations.apartments[currentLang] || translations.apartments.nl;

    const [selectedApartment, setSelectedApartment] = useState('');

    const selectedApt = apartments.find(apt => apt.id === selectedApartment);

    const handleContinue = () => {
        if (selectedApartment) {
            // Store selected apartment and navigate to login
            localStorage.setItem('selected_apartment', selectedApartment);
            router.push('/login');
        }
    };

    return (
        <div className={styles.page}>
            <div className={styles.container}>
                <div className={styles.card}>
                    <div className={styles.header}>
                        <h1 className={styles.title}>{t.title}</h1>
                        <p className={styles.subtitle}>{t.subtitle}</p>
                    </div>

                    <div className={styles.content}>
                        <div className={styles.form}>
                            <div className={styles.selectWrapper}>
                                <label className={styles.selectLabel}>{t.selectLabel}</label>
                                <select
                                    className={styles.select}
                                    value={selectedApartment}
                                    onChange={(e) => setSelectedApartment(e.target.value)}
                                >
                                    <option value="">{t.selectPlaceholder}</option>
                                    {apartments.map((apt) => (
                                        <option key={apt.id} value={apt.id}>
                                            {apt.address}, {apt.city} - €{apt.price} {t.price}
                                        </option>
                                    ))}
                                </select>
                            </div>

                            {selectedApt && (
                                <div className={styles.previewCard}>
                                    <h3 className={styles.previewTitle}>
                                        {selectedApt.address}
                                    </h3>
                                    <div className={styles.previewDetails}>
                                        <div className={styles.previewItem}>
                                            <span className={styles.previewValue}>€{selectedApt.price}</span>
                                            <span className={styles.previewLabel}>{t.price}</span>
                                        </div>
                                        <div className={styles.previewItem}>
                                            <span className={styles.previewValue}>{selectedApt.rooms}</span>
                                            <span className={styles.previewLabel}>{t.rooms}</span>
                                        </div>
                                        <div className={styles.previewItem}>
                                            <span className={styles.previewValue}>{selectedApt.surface}</span>
                                            <span className={styles.previewLabel}>{t.surface}</span>
                                        </div>
                                    </div>
                                </div>
                            )}

                            <Button
                                onClick={handleContinue}
                                disabled={!selectedApartment}
                                fullWidth
                                size="lg"
                            >
                                {t.continueBtn}
                            </Button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default AppartementenSelectie;
