import React from 'react';
import { GraduationCap, Briefcase, Building2 } from 'lucide-react';
import styles from './WorkStatusSelector.module.css';

const workStatuses = [
    { id: 'student', icon: GraduationCap, iconClass: 'iconStudent' },
    { id: 'werknemer', icon: Briefcase, iconClass: 'iconEmployee' },
    { id: 'ondernemer', icon: Building2, iconClass: 'iconEntrepreneur' },
];

const labels = {
    nl: {
        student: 'Student',
        werknemer: 'Werknemer',
        ondernemer: 'Ondernemer',
    },
    en: {
        student: 'Student',
        werknemer: 'Employee',
        ondernemer: 'Entrepreneur',
    }
};

const WorkStatusSelector = ({ value, onChange, lang = 'nl' }) => {
    const t = labels[lang] || labels.nl;

    return (
        <div className={styles.container}>
            {workStatuses.map(({ id, icon: Icon, iconClass }) => (
                <button
                    key={id}
                    type="button"
                    className={`${styles.button} ${value === id ? styles.buttonActive : ''}`}
                    onClick={() => onChange(id)}
                >
                    <div className={`${styles.icon} ${styles[iconClass]}`}>
                        <Icon size={24} />
                    </div>
                    <span className={styles.label}>{t[id]}</span>
                </button>
            ))}
        </div>
    );
};

export default WorkStatusSelector;
