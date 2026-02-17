'use client';

import React from 'react';
import Link from 'next/link';
import { useSelector } from 'react-redux';
import styles from './Neighborhoods.module.css';
import { translations } from '../data/translations';

const neighborhoods = [
    { id: 'centrum', name: 'Centrum', image: '/images/centrum-neighborhood-8xGBhlo4.jpg' },
    { id: 'jordaan', name: 'Jordaan', image: '/images/jordaan-neighborhood-D10TAM1c.jpg' },
    { id: 'noord', name: 'Noord', image: '/images/noord-neighborhood-C3afdJ-w.jpg' },
    { id: 'oost', name: 'Oost', image: '/images/oost-neighborhood-D0P6YpX3.jpg' },
    { id: 'de-pijp', name: 'De Pijp', image: '/images/de-pijp-neighborhood-CerLEEUD.jpg' },
    { id: 'oud-zuid', name: 'Oud-Zuid', image: '/images/oud-zuid-neighborhood-B-g-rFNe.jpg' },
    { id: 'zuidas', name: 'Zuidas', image: '/images/zuidas-neighborhood-BS6cve9Y.jpg' },
    { id: 'zeeburg', name: 'Zeeburg', image: '/images/zeeburg-neighborhood-BtRlc8ql.jpg' },
    { id: 'nieuw-west', name: 'Nieuw-West', image: '/images/nieuw-west-neighborhood-DhzrAv7H.jpg' },
];

const Neighborhoods = () => {
    const currentLang = useSelector((state) => state.ui.language);
    const t = translations.neighborhoods[currentLang] || translations.neighborhoods.en;

    return (
        <div className={styles.pageContainer}>
            <section className={styles.heroSection}>
                <div className={styles.container}>
                    <h1 className={styles.heroTitle}>{t.title}</h1>
                    <p className={styles.heroSubtitle}>
                        {t.subtitle}
                    </p>
                </div>
            </section>

            <section className={styles.gridSection}>
                <div className={styles.container}>
                    <div className={styles.grid}>
                        {neighborhoods.map((neighborhood) => (
                            <Link
                                key={neighborhood.id}
                                href={`/${currentLang}/neighborhood/${neighborhood.id}`}
                                className={styles.card}
                            >
                                <div className={styles.imageWrapper}>
                                    <img
                                        src={neighborhood.image}
                                        alt={neighborhood.name}
                                        className={styles.image}
                                        loading="lazy"
                                    />
                                </div>
                                <div className={styles.cardOverlay}>
                                    <div className={styles.cardContent}>
                                        <h3 className={styles.cardTitle}>{neighborhood.name}</h3>
                                        <p className={styles.cardLink}>{t.readMore} →</p>
                                    </div>
                                </div>
                            </Link>
                        ))}
                    </div>
                </div>
            </section>
        </div>
    );
};

export default Neighborhoods;
