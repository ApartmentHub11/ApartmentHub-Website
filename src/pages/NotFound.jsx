import React from 'react';
import { Link } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { translations } from '../data/translations';
import Button from '../components/ui/Button';
import styles from './NotFound.module.css';

const NotFound = () => {
    const currentLang = useSelector((state) => state.ui.language);
    const t = translations.notFound[currentLang] || translations.notFound.nl;

    const homePath = currentLang === 'en' ? '/en' : '/';

    return (
        <div className={styles.page}>
            <div className={styles.content}>
                <div className={styles.errorCode}>404</div>
                <h1 className={styles.title}>{t.title}</h1>
                <p className={styles.message}>{t.message}</p>
                <Link to={homePath}>
                    <Button size="lg">{t.backHome}</Button>
                </Link>
            </div>
        </div>
    );
};

export default NotFound;
