import React from 'react';
import { TrendingUp, Home, Users } from 'lucide-react';
import styles from './MarketIndicators.module.css';

const MarketIndicators = ({ trends, neighborhood, isNL = true }) => {
    const getIndicatorClass = (value, thresholdLow, thresholdHigh, reverse = false) => {
        if (reverse) {
            if (value <= thresholdLow) return styles.indicatorRed;
            if (value <= thresholdHigh) return styles.indicatorYellow;
            return styles.indicatorGreen;
        }
        if (value <= thresholdLow) return styles.indicatorRed;
        if (value <= thresholdHigh) return styles.indicatorYellow;
        return styles.indicatorGreen;
    };

    const indicators = [
        {
            title: isNL ? 'Huurgroei (5 jaar)' : 'Rent Growth (5 years)',
            value: `+${trends.rentGrowth}%`,
            icon: TrendingUp,
            indicatorClass: trends.rentGrowth > 15 ? styles.indicatorRed : trends.rentGrowth > 10 ? styles.indicatorYellow : styles.indicatorGreen,
            description: isNL
                ? (trends.rentGrowth > 15 ? 'Hoge groei' : trends.rentGrowth > 10 ? 'Gemiddelde groei' : 'Stabiele groei')
                : (trends.rentGrowth > 15 ? 'High growth' : trends.rentGrowth > 10 ? 'Average growth' : 'Stable growth')
        },
        {
            title: isNL ? 'Koopprijsgroei (5 jaar)' : 'Purchase Growth (5 years)',
            value: `+${trends.purchaseGrowth}%`,
            icon: TrendingUp,
            indicatorClass: trends.purchaseGrowth > 40 ? styles.indicatorRed : trends.purchaseGrowth > 30 ? styles.indicatorYellow : styles.indicatorGreen,
            description: isNL
                ? (trends.purchaseGrowth > 40 ? 'Zeer hoge groei' : trends.purchaseGrowth > 30 ? 'Hoge groei' : 'Gemiddelde groei')
                : (trends.purchaseGrowth > 40 ? 'Very high growth' : trends.purchaseGrowth > 30 ? 'High growth' : 'Average growth')
        },
        {
            title: isNL ? 'Vraag Index' : 'Demand Index',
            value: `${trends.demandIndex}/10`,
            icon: Users,
            indicatorClass: getIndicatorClass(trends.demandIndex, 3, 6),
            description: isNL
                ? (trends.demandIndex > 7 ? 'Zeer hoge vraag' : trends.demandIndex > 5 ? 'Gemiddelde vraag' : 'Lage vraag')
                : (trends.demandIndex > 7 ? 'Very high demand' : trends.demandIndex > 5 ? 'Average demand' : 'Low demand')
        },
        {
            title: isNL ? 'Beschikbaarheid' : 'Availability',
            value: `${trends.availabilityIndex}/10`,
            icon: Home,
            indicatorClass: getIndicatorClass(trends.availabilityIndex, 3, 6, true),
            description: isNL
                ? (trends.availabilityIndex <= 3 ? 'Zeer schaars' : trends.availabilityIndex <= 6 ? 'Beperkt aanbod' : 'Ruim aanbod')
                : (trends.availabilityIndex <= 3 ? 'Very scarce' : trends.availabilityIndex <= 6 ? 'Limited supply' : 'Good availability')
        }
    ];

    return (
        <div className={styles.container}>
            <h4 className={styles.title}>
                {isNL ? `Marktindicatoren voor ${neighborhood}` : `Market Indicators for ${neighborhood}`}
            </h4>
            <div className={styles.grid}>
                {indicators.map((indicator, index) => (
                    <div
                        key={index}
                        className={`${styles.card} ${indicator.indicatorClass}`}
                    >
                        <div className={styles.cardHeader}>
                            <indicator.icon className={styles.icon} />
                            <span className={styles.value}>
                                {indicator.value}
                            </span>
                        </div>
                        <h5 className={styles.cardTitle}>
                            {indicator.title}
                        </h5>
                        <p className={styles.cardDesc}>
                            {indicator.description}
                        </p>
                    </div>
                ))}
            </div>
        </div>
    );
};

export default MarketIndicators;
