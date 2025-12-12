import React, { useState, useRef, useEffect } from 'react';
import { ChevronDown } from 'lucide-react';
import styles from './CustomSelect.module.css';

const CustomSelect = ({ value, onChange, options, placeholder, required }) => {
    const [isOpen, setIsOpen] = useState(false);
    const containerRef = useRef(null);

    // Close dropdown when clicking outside
    useEffect(() => {
        const handleClickOutside = (event) => {
            if (containerRef.current && !containerRef.current.contains(event.target)) {
                setIsOpen(false);
            }
        };

        document.addEventListener('mousedown', handleClickOutside);
        return () => {
            document.removeEventListener('mousedown', handleClickOutside);
        };
    }, []);

    const handleSelect = (optionValue) => {
        onChange(optionValue);
        setIsOpen(false);
    };

    const selectedOption = options.find(opt => opt.value === value);

    return (
        <div className={styles.selectContainer} ref={containerRef}>
            <div
                className={`${styles.selectTrigger} ${!value ? styles.placeholder : ''}`}
                onClick={() => setIsOpen(!isOpen)}
                tabIndex={0}
            >
                <span>
                    {selectedOption ? selectedOption.label : (placeholder || "Select...")}
                </span>
                <ChevronDown className={`${styles.selectIcon} ${isOpen ? styles.open : ''}`} />
            </div>

            {isOpen && (
                <ul className={styles.optionsList}>
                    {options.map((option) => (
                        <li
                            key={option.value}
                            className={`${styles.option} ${value === option.value ? styles.selected : ''}`}
                            onClick={() => handleSelect(option.value)}
                        >
                            {option.label}
                        </li>
                    ))}
                </ul>
            )}

            {/* Hidden native select for form validation if needed */}
            <select
                value={value}
                onChange={() => { }}
                required={required}
                style={{ position: 'absolute', bottom: 0, left: '50%', opacity: 0, pointerEvents: 'none', width: '1px', height: '1px' }}
                tabIndex={-1}
            >
                <option value="" disabled>Select...</option>
                {options.map(opt => (
                    <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
            </select>
        </div>
    );
};

export default CustomSelect;
