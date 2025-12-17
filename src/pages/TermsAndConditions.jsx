import React from 'react';
import { useSelector } from 'react-redux';
import styles from './LegalPage.module.css';

const TermsAndConditions = () => {
    const currentLang = useSelector((state) => state.ui.language);
    const isNL = currentLang !== 'en';

    return (
        <div className={styles.page}>
            <div className={styles.container}>
                <h1 className={styles.title}>
                    {isNL ? 'Algemene Voorwaarden' : 'Terms and Conditions'}
                </h1>

                {/* Artikel 1 */}
                <section className={styles.section}>
                    <h2 className={styles.sectionTitle}>Artikel 1 Toepasselijkheid</h2>
                    <p className={styles.paragraph}>
                        Deze Bemiddelingsvoorwaarden zijn van toepassing op alle aanbiedingen en op alle bemiddelingsopdrachten, alsmede de daaruit voortvloeiende aanvullende bemiddelingsovereenkomst(en) en afspraken tussen Apartmenthub en de woningzoekende, hierna te nemen 'Opdrachtgever'.
                    </p>
                </section>

                {/* Artikel 2 */}
                <section className={styles.section}>
                    <h2 className={styles.sectionTitle}>Artikel 2 Definities</h2>
                    <p className={styles.paragraph}>
                        <strong>2.1.</strong> Apartmenthub: Een woningbemiddelingsbureau ingeschreven bij de Kamer van Koophandel Amsterdam onder nummer: 74255142 te noemen onder webadres: https://apartmenthub.nl, hierna te noemen 'Makelaar'.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>2.2.</strong> Woningzoekende: Iedere natuurlijke of rechtspersoon, die de Makelaar opdracht geeft om te bemiddelen bij het zoeken van woonruimte die niet tot de portefeuille van de Makelaar behoort.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>2.3.</strong> Onder bemiddeling wordt verstaan: de inspanningsverplichting van Makelaar gericht op het tegen betaling van een bemiddelingsvergoeding (courtage) door Opdrachtgever in contact brengen van Opdrachtgever met potentiële verhuurder(s), opdat Opdrachtgever met een verhuurder van een woonruimte een huurovereenkomst sluit, waaronder is begrepen de begeleiding door Makelaar bij bezichtiging(en) van een of meer woonruimte(n) als bedoeld in artikel 7:425 BW.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>2.4.</strong> Onder bemiddelingsvergoeding of courtage wordt verstaan de door Opdrachtgever aan Makelaar verschuldigde tegenprestatie voor diens bemiddelingswerkzaamheden.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>2.5.</strong> Bepalingen die afwijken van deze algemene bemiddelingsvoorwaarden maken alleen deel uit van de tussen partijen gesloten overeenkomst indien en voor zover partijen dat uitdrukkelijk schriftelijk zijn overeengekomen.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>2.6.</strong> Onder 'schriftelijk' wordt in deze algemene bemiddelingsvoorwaarden tevens verstaan: per email, per fax of enige andere wijze van communicatie die met het oog op de stand der techniek en de in het maatschappelijk verkeer geldende opvattingen hiermee gelijk kan worden gesteld.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>2.7.</strong> De door Makelaar te vervaardigen c.q. door Opdrachtgever verstrekte schriftelijke adviezen, documenten, (taxatie)rapporten, onderzoeken, e.d. zullen in het navolgende worden aangeduid als 'de bescheiden'. Onder 'de bescheiden' worden verstaan schriftelijke stukken en op andere media vastgelegde werken, zoals op computerschijven, op usb-sticks of welke andere gegevensdragers ook. Een en ander, tenzij partijen uitdrukkelijk schriftelijk anders zijn overeengekomen.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>2.8.</strong> Makelaar behoudt zich het recht voor om bij gewijzigde regelgeving de algemene bemiddelingsvoorwaarden van Makelaar te wijzigen.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>2.9.</strong> Het om welke reden dan ook niet van toepassing zijn van een (deel van een) bepaling van deze algemene bemiddelingsvoorwaarden laat de toepasselijkheid van de overige bepalingen onverlet.
                    </p>
                </section>

                {/* Artikel 3 */}
                <section className={styles.section}>
                    <h2 className={styles.sectionTitle}>Artikel 3 Overeenkomsten, opdrachten</h2>
                    <p className={styles.paragraph}>
                        <strong>3.1.</strong> Mondelinge afspraken binden Makelaar eerst nadat deze schriftelijk door Makelaar zijn bevestigd dan wel zodra Makelaar met instemming van Opdrachtgever een aanvang met de uitvoeringshandelingen heeft gemaakt.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>3.2.</strong> Aanvullingen of wijzigingen op de algemene bemiddelingsvoorwaarden of anderszins wijzigingen of aanvullingen op de overeenkomst worden eerst na schriftelijke bevestiging door Makelaar bindend.
                    </p>
                </section>

                {/* Artikel 4 */}
                <section className={styles.section}>
                    <h2 className={styles.sectionTitle}>Artikel 4 Verplichtingen van Opdrachtgever & verschuldigdheid van courtage</h2>
                    <p className={styles.paragraph}>
                        <strong>4.1.</strong> Opdrachtgever dient ervoor te zorgen dat alle voor de uitvoering van de overeenkomst benodigde gegevens tijdig en in de door Makelaar gewenste vorm ter beschikking worden gesteld.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>4.2.</strong> Opdrachtgever verleent volledige medewerking aan een deugdelijke uitvoering van de bemiddelingsovereenkomst en onthoudt zich van handelingen die dit zouden kunnen belemmeren.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>4.3.</strong> Indien Opdrachtgever of diens relaties gaan wonen in een woonruimte waarvan de gegevens via de Makelaar zijn verkregen, is Opdrachtgever courtage verschuldigd, ongeacht of de huurovereenkomst door bemiddeling van de Makelaar tot stand is gekomen.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>4.4.</strong> Indien om welke reden dan ook Opdrachtgever niet gaat wonen in de woning waarvoor door bemiddeling van Makelaar een huurovereenkomst tot stand is gekomen, of indien deze huurovereenkomst wordt beëindigd, vernietigd of ontbonden, is Opdrachtgever een bedrag verschuldigd van <strong>1 maand huur exclusief btw</strong>, zonder recht op gehele of gedeeltelijke restitutie.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>4.5.</strong> Indien Opdrachtgever na akkoord voor het huren van een woonruimte afziet van de huur om redenen die niet aan Makelaar zijn toe te rekenen, is Opdrachtgever de courtage verschuldigd die zou gelden indien de huurovereenkomst wél tot stand zou zijn gekomen. Daarnaast dient Opdrachtgever Makelaar te vrijwaren voor mogelijke schadeclaims van de verhuurder.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>4.6.</strong> Indien Opdrachtgever verplichtingen niet nakomt, mag Makelaar de uitvoering van de overeenkomst opschorten. Kosten en gevolgen hiervan komen volledig voor rekening van Opdrachtgever.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>4.7.</strong> Indien Opdrachtgever de Makelaar verzoekt een huurvoorstel in te dienen bij een derde en vervolgens, om redenen die niet aan Makelaar zijn toe te rekenen, afziet van het object, is Opdrachtgever een bedrag verschuldigd van <strong>1 maand huur exclusief btw</strong>.
                    </p>
                </section>

                {/* Artikel 5 */}
                <section className={styles.section}>
                    <h2 className={styles.sectionTitle}>Artikel 5 Persoonsgegevens</h2>
                    <p className={styles.paragraph}>
                        De persoonsgegevens van Opdrachtgever worden opgenomen in de administratie van Makelaar. Makelaar verstrekt zonder toestemming van Opdrachtgever geen gegevens aan derden. De geregistreerde gegevens worden uitsluitend door Makelaar gebruikt ten behoeve van de uitvoering van door haar met Opdrachtgever gesloten overeenkomsten.
                    </p>
                </section>

                {/* Artikel 6 */}
                <section className={styles.section}>
                    <h2 className={styles.sectionTitle}>Artikel 6 Voortgang, uitvoering opdracht/overeenkomst</h2>
                    <p className={styles.paragraph}>
                        <strong>6.1.</strong> Makelaar is gehouden de opdracht/overeenkomst op deskundige, zorgvuldige wijze en conform de hiervoor in haar branche geldende maatstaven uit te voeren.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>6.2.</strong> Makelaar kan niet eerder verplicht worden met de uitvoering van de werkzaamheden te beginnen, dan nadat alle daarvoor noodzakelijk gegevens in haar bezit zijn.
                    </p>
                </section>

                {/* Artikel 7 */}
                <section className={styles.section}>
                    <h2 className={styles.sectionTitle}>Artikel 7 Duur overeenkomst, inspanningsverplichting makelaar</h2>
                    <p className={styles.paragraph}>
                        <strong>7.1.</strong> Een overeenkomst tot bemiddeling loopt voor onbepaalde tijd, tenzij schriftelijk anders is overeengekomen.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>7.2.</strong> Makelaar zal zich naar beste kunnen en weten inspannen om het door Opdrachtgever gewenste c.q. beoogde resultaat te bereiken. Dit is te allen tijde een inspanningsverplichting van Makelaar en geen resultaatsverplichting. Indien voornoemd resultaat uitblijft, ontslaat dit Opdrachtgever derhalve niet van zijn verplichtingen jegens Makelaar, met uitzondering van eventuele verplichtingen die door partijen uitdrukkelijk gekoppeld zijn aan het bereiken van het beoogde resultaat.
                    </p>
                </section>

                {/* Artikel 8 */}
                <section className={styles.section}>
                    <h2 className={styles.sectionTitle}>Artikel 8 Einde en opzegging van de bemiddelingsovereenkomst</h2>
                    <p className={styles.paragraph}>
                        <strong>8.1.</strong> Tenzij anders overeengekomen en onverminderd het overigens bepaalde in deze algemene bemiddelingsvoorwaarden, eindigt de bemiddelingsovereenkomst onder meer door:
                    </p>
                    <ul className={styles.list}>
                        <li>a. vervulling van de overeenkomst door Makelaar;</li>
                        <li>b. opzegging door Opdrachtgever;</li>
                        <li>c. opzegging door Makelaar.</li>
                    </ul>
                    <p className={styles.paragraphMt}>
                        <strong>8.2.</strong> De overeenkomst is vervuld zodra het beoogde resultaat is bereikt.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>8.3.</strong> Opdrachtgever en Makelaar zijn bevoegd om deze overeenkomst op ieder moment op te zeggen.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>8.4.</strong> Partijen kunnen aan de beëindiging van de overeenkomst door opzegging geen recht op schadevergoeding ontlenen, tenzij wordt opgezegd vanwege het tekortschieten in de nakoming van een of meer verplichtingen door de andere partij.
                    </p>
                </section>

                {/* Artikel 9 */}
                <section className={styles.section}>
                    <h2 className={styles.sectionTitle}>Artikel 9 Bemiddelingscourtage</h2>
                    <p className={styles.paragraph}>
                        <strong>9.1.</strong> De woningzoekende geeft de Makelaar opdracht tot het zoeken van woonruimte die aansluit bij de opgegeven woonwensen. De Makelaar werkt volgens het <em>No Cure No Pay</em>-principe. Wanneer door bemiddeling van de Makelaar een huurovereenkomst tot stand komt, is Opdrachtgever een bemiddelingscourtage verschuldigd gelijk aan <strong>één maand huur exclusief btw</strong>.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>Aanvullende regeling:</strong><br />
                        Indien de maandhuur <strong>lager dan € 2.000</strong> bedraagt én de huurovereenkomst een looptijd heeft van <strong>meer dan 12 maanden</strong>, bedraagt de courtage <strong>twee maanden huur exclusief btw</strong>.
                    </p>
                    <p className={styles.paragraphMt}>
                        De courtage dient volledig te zijn voldaan voordat de sleutels worden overgedragen.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>9.2.</strong> Indien de betalingstermijn wordt overschreden, volgt een aanmaningsprocedure. Na de tweede aanmaning is wettelijke rente verschuldigd en worden buitengerechtelijke incassokosten in rekening gebracht van 15% van het factuurbedrag (minimaal € 250).
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>9.3.</strong> Indien blijkt dat de woningzoekende een eerder door Makelaar aangeboden woonruimte alsnog accepteert zonder medeweten van Makelaar, is de volledige courtage verschuldigd.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>9.4.</strong> Indien de huurovereenkomst op andere wijze tot stand komt terwijl de Makelaar een bemiddelingsopdracht had, is Opdrachtgever een boete verschuldigd van <strong>één maand huur exclusief btw</strong>.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>9.5.</strong> Een woonruimte wordt pas aan de woningzoekende beschikbaar gesteld nadat:
                    </p>
                    <ul className={styles.list}>
                        <li>de huurovereenkomst door alle partijen is ondertekend;</li>
                        <li>huur en borg zijn voldaan;</li>
                        <li>de courtage <strong>exclusief btw</strong> volledig is betaald.</li>
                    </ul>
                    <p className={styles.paragraphMt}>
                        <strong>9.6.</strong> Aan de beëindiging van de overeenkomst door opzegging kunnen geen rechten op schadevergoeding worden ontleend, tenzij de opzegging het gevolg is van tekortschieten van de andere partij.
                    </p>
                </section>

                {/* Artikel 10 */}
                <section className={styles.section}>
                    <h2 className={styles.sectionTitle}>Artikel 10 Aansprakelijkheid</h2>
                    <p className={styles.paragraph}>
                        <strong>10.1.</strong> Indien Makelaar bemiddelt bij het tot stand brengen van een huurovereenkomst tussen verhuurder en huurder is Makelaar nimmer partij bij de huurovereenkomst en hij is niet aansprakelijk voor de inhoud en de uitvoering van de huurovereenkomst. Makelaar is in geen geval aansprakelijk voor de schade van Opdrachtgever die het gevolg is van de situatie dat de huurprijs en/of de overeengekomen service(kosten) en/of de bijkomende al dan niet eenmalige vergoedingen niet in overeenstemming zijn met de wet.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>10.2.</strong> Makelaar kwijt zich van haar taak zoals van een bedrijf in haar branche mag worden verwacht, maar aanvaardt geen enkele aansprakelijkheid voor schade, met inbegrip van gevolgschade, bedrijfsschade, winstdervingen en/of stagnatieschade, die het gevolg is van handelen of nalaten van Makelaar, haar personeel dan wel door haar ingeschakelde derden.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>10.3.</strong> Makelaar is niet aansprakelijk voor schade die Opdrachtgever lijdt ten gevolge van handelingen of het nalaten hiervan door de andere partij bij de door bemiddeling van Makelaar tot stand gekomen huurovereenkomst.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>10.4.</strong> De in dit artikel opgenomen beperkingen van de aansprakelijkheid gelden niet indien de schade te wijten is aan opzet en/of bewuste roekeloosheid van Makelaar.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>10.5.</strong> Onverminderd het bepaalde in de overige leden van dit artikel is de aansprakelijkheid te allen tijde beperkt tot het bedrag van de door de assuradeur van Makelaar in het voorkomende geval te verstrekken uitkering, voor zover Makelaar hiervoor verzekerd is.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>10.6.</strong> Indien Makelaar niet verzekerd is als bedoeld in het vorige lid is de aansprakelijkheid van Makelaar te allen tijde beperkt tot twee maal de hoogte van de door Makelaar aan Opdrachtgever voor haar werkzaamheden en/of diensten in rekening gebrachte en/of te brengen courtage.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>10.7.</strong> Makelaar is niet aansprakelijk voor de gevolgen van eventuele schade en/of gebreken aan de woning die bij de aanvaarding door Opdrachtgever van de woning aanwezig is. Het is aan Opdrachtgever zelf de woning te controleren op eventuele schade en/of gebreken en zo nodig de verhuurder daarop aan te spreken.
                    </p>
                </section>

                {/* Artikel 11 */}
                <section className={styles.section}>
                    <h2 className={styles.sectionTitle}>Artikel 11 Bevoegde rechter, toepasselijk recht</h2>
                    <p className={styles.paragraph}>
                        <strong>11.1.</strong> Op de tussen Makelaar en Opdrachtgever gesloten overeenkomst is uitsluitend Nederlands recht van toepassing. De geschillen die uit deze overeenkomst voortvloeien zullen eveneens naar Nederlands recht worden beslecht.
                    </p>
                    <p className={styles.paragraphMt}>
                        <strong>11.2.</strong> Eventuele geschillen zullen worden beslecht door de bevoegde Nederlandse rechter, zij het dat Makelaar, voor zover de wet zich daar niet dwingendrechtelijk tegen verzet, de bevoegdheid toekomt een zaak aanhangig te maken voor de bevoegde rechter in de plaats waar Makelaar is gevestigd.
                    </p>
                </section>
            </div>
        </div>
    );
};

export default TermsAndConditions;
