create table sede 
(
	cod_sede serial primary key, 
	via varchar(30) NOT NULL,
	num_civico int NOT NULL,
	luogo varchar(30) NOT NULL, 
	
	constraint unico_luogo unique (via, num_civico, luogo)
    
)

create table comitato 
(
	cod_comitato serial primary key,
    tipo_c varchar (2) not null,
    nome_c varchar (30) not null
)

create table coordinatore 
(
	cod_coordinatore serial primary key, 
	nome varchar(30) NOT NULL,
    cognome varchar(30) NOT NULL, 
	data_n date NOT NULL
	
)

create table partecipante 
(
	cod_partecipante serial primary key, 
	nome varchar(30) NOT NULL,
	num_civico int NOT NULL,
	cognome varchar(30) NOT NULL, 
	email varchar(30),
	titolo varchar(30),
	istituzione varchar(30)
	
)

create table organizzatore 
(
	cod_organizzatore serial primary key, 
	nome varchar(30) NOT NULL,
	num_civico int NOT NULL,
	cognome varchar(30) NOT NULL, 
	email varchar(30),
	titolo varchar(30),
	istituzione varchar(30),
	cod_comitato serial,
	
 	foreign key (cod_comitato) references comitato (cod_comitato)
	on delete restrict
	on update restrict
)

create table conferenza 
(
	cod_conferenza serial primary key, 
	sponsor varchar(30),
	descrizione varchar(100) NOT NULL,
	ente varchar(30) NOT NULL, 
	spesa integer NOT NULL,
	data_i date NOT NULL,
	data_f date NOT NULL,
	cod_sede serial,
	
	foreign key (cod_sede) references sede (cod_sede)
	on delete restrict
	on update restrict
	
)

create table sessione 
(
	cod_sessione serial primary key, 
	data_prestabilita date NOT NULL,
	orario_predefinito time NOT NULL,
	cod_conferenza serial,
	cod_coordinatore serial,
	
	foreign key (cod_conferenza) references conferenza (cod_conferenza)
	on delete cascade
	on update restrict,
	
	foreign key (cod_coordinatore) references coordinatore (cod_coordinatore)
	on delete cascade
	on update cascade
	
)

create table intervento
(
	cod_intervento serial primary key, 
	abstract varchar(100) NOT NULL,
    cod_sessione serial,
	
	foreign key (cod_sessione) references sessione(cod_sessione)
	on delete restrict
	on update restrict
	
)

create table occasione_extra
(
	cod_occasione serial primary key, 
	tipo_evento_s varchar(2),
	tipo_spazio_i varchar(2),
	cod_sessione serial,
	
	foreign key (cod_sessione) references sessione (cod_sessione)
	on delete restrict
	on update restrict,
    
    descrizione varchar (30) not null
	
)

create table ammissione 
(
	cod_sessione serial , 
	cod_partecipante serial,
	partecipante_s varchar(2) NOT NULL,
	keyonote_speaker varchar(2) NOT NULL,
	
	foreign key (cod_sessione) references sessione (cod_sessione)
	on delete restrict
	on update restrict,
	
	foreign key (cod_partecipante) references  partecipante (cod_partecipante)
	on delete cascade
	on update cascade,
	
	primary key (cod_sessione,cod_partecipante)
)

create table gestione 
(
	cod_conferenza serial , 
	cod_organizzatore serial,

	
	foreign key (cod_conferenza) references conferenza (cod_conferenza)
	on delete restrict
	on update restrict,
	
	foreign key (cod_organizzatore) references organizzatore(cod_organizzatore)
	on delete cascade
	on update cascade,
	
	primary key (cod_conferenza,cod_organizzatore)
)


create table tenuta 
(
	cod_conferenza serial , 
	cod_sede serial,
	
	foreign key (cod_sede) references sede (cod_sede)
	on delete restrict
	on update restrict,
	
	foreign key (cod_conferenza) references  conferenza (cod_conferenza)
	on delete cascade
	on update cascade,
	
	primary key (cod_sede,cod_conferenza)
)



ALTER TABLE sede
ADD CONSTRAINT check_lunghezza_via
CHECK (length(via) <= 30);

ALTER TABLE conferenza
ADD CONSTRAINT check_spesa_conferenza
CHECK (spesa >= 0);

ALTER TABLE sede
ADD CONSTRAINT chk_num_civico_positive
CHECK (num_civico > 0);

ALTER TABLE coordinatore
ADD CONSTRAINT chk_data_nascita_valida
CHECK (data_n <= CURRENT_DATE);

ALTER TABLE sede
ADD CONSTRAINT num_civico_valido 
CHECK (num_civico >= 1 AND num_civico <= 999);

ALTER TABLE comitato 
ADD CONSTRAINT check_tipo_scientifico 
CHECK (tipo_c IN ('sc', 'lo'));



CREATE OR REPLACE FUNCTION check_div_ses()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT *
        FROM sessione AS s1 
        JOIN conferenza AS co ON s1.cod_conferenza = co.cod_conferenza 
        JOIN tenuta AS t ON t.cod_conferenza = co.cod_conferenza
        JOIN sessione AS s2 ON s2.cod_conferenza = co.cod_conferenza 
        WHERE s1.cod_sessione <> s2.cod_sessione 
            AND s1.cod_conferenza = s2.cod_conferenza 
            AND co.cod_sede = t.cod_sede
            AND (s1.data_predefinita = co.data_inizio OR s2.data_predefinita = co.data_inizio)
    ) THEN
        RAISE EXCEPTION 'La condizione di divisione delle sessioni non è stata rispettata.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_div_ses_trigger
BEFORE INSERT OR UPDATE OR DELETE ON sessione
FOR EACH ROW
EXECUTE FUNCTION check_div_ses();




CREATE OR REPLACE FUNCTION check_stessi_O() RETURNS TRIGGER AS $$
BEGIN
	IF EXISTS (
		SELECT o.cod_conferenza, o.cod_organizzatore
		FROM organizzatore AS o 
		JOIN comitato AS co ON o.cod_comitato = co.cod_comitato 
		JOIN gestione AS ge ON ge.cod_organizzatore = o.cod_organizzatore
		JOIN organizzatore AS o2 ON o2.cod_conferenza = ge.cod_conferenza AND o2.cod_organizzatore <> o.cod_organizzatore
		WHERE o.cod_conferenza = o2.cod_conferenza
		GROUP BY o.cod_conferenza, o.cod_organizzatore
		HAVING COUNT(*) >= 3
	) THEN
		RAISE EXCEPTION 'L''assertion stessi_O è violata';
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_stessi_O_trigger
BEFORE INSERT OR UPDATE ON organizzatore
FOR EACH ROW
EXECUTE FUNCTION check_stessi_O();



CREATE OR REPLACE FUNCTION check_ammissione_partecipante()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT p.cod_partecipante
        FROM partecipante AS p
        LEFT JOIN ammissione AS a ON p.cod_partecipante = a.cod_partecipante
        WHERE a.cod_partecipante IS NULL
    ) THEN
        RETURN NEW;
    ELSE
        RAISE EXCEPTION 'La tabella ammissione deve contenere solo partecipanti che esistono nella tabella partecipante.';
    END IF;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER ammissione_partecipante_trigger
AFTER INSERT OR UPDATE ON ammissione
FOR EACH ROW
EXECUTE FUNCTION check_ammissione_partecipante();
Questo trigger controlla che ogni volta che viene inserita o aggiornata una riga nella tabella "ammissione", tutti i codici di partecipante esistenti nella tabella "ammissione" corrispondano a un codice di partecipante esistente nella tabella "partecipante". Se esiste almeno un codice di partecipante in "ammissione" che non esiste in "partecipante", il trigger genera un'eccezione. In caso contrario, il trigger consente l'operazione di inserimento o aggiornamento.



CREATE OR REPLACE FUNCTION check_sede_conferenza()
RETURNS TRIGGER AS $$
BEGIN
    -- controlla se la sede è già assegnata ad una conferenza in corso
    IF EXISTS(SELECT * FROM conferenza 
              WHERE cod_sede = NEW.cod_sede 
              AND (data_i <= NEW.data_f AND data_f >= NEW.data_i)) THEN
        RAISE EXCEPTION 'La sede è già assegnata ad una conferenza in corso!';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sede_conferenza_trigger
BEFORE INSERT OR UPDATE ON conferenza
FOR EACH ROW
EXECUTE FUNCTION check_sede_conferenza();




CREATE OR REPLACE FUNCTION aggiorna_spesa()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE conferenza
    SET spesa = spesa + NEW.spesa
    WHERE cod_conferenza = NEW.cod_conferenza;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER aggiorna_spesa_intervento
AFTER INSERT ON intervento
FOR EACH ROW
EXECUTE FUNCTION aggiorna_spesa();



CREATE OR REPLACE FUNCTION check_budget()
RETURNS TRIGGER AS $$
BEGIN
  DECLARE
    budget_tot INTEGER;
    spesa_tot INTEGER;
  BEGIN
    -- Recupero il budget totale dell'ente che sponsorizza la conferenza
    SELECT budget INTO budget_tot FROM ente WHERE nome = NEW.ente;
    
    -- Recupero la spesa totale delle conferenze sponsorizzate dall'ente
    SELECT COALESCE(SUM(spesa), 0) INTO spesa_tot FROM conferenza WHERE ente = NEW.ente;
    
    -- Controllo se la spesa prevista per la nuova conferenza supera il budget totale dell'ente
    IF NEW.spesa > budget_tot - spesa_tot THEN
      RAISE EXCEPTION 'La spesa prevista supera il budget totale dell''ente.';
    END IF;
    
    RETURN NEW;
  END;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_budget_trigger
BEFORE INSERT ON conferenza
FOR EACH ROW
EXECUTE FUNCTION check_budget();


per aggiornare una tabella "tenuta" ogni volta che viene inserita una nuova conferenza nella tabella "conferenza" con una data di inizio successiva alla data di fine dell ultima conferenza tenuta nella stessa sede:

postgresqlCopy code


CREATE OR REPLACE FUNCTION update_tenuta() 
RETURNS TRIGGER AS $$
DECLARE
  last_conf date;
BEGIN
  SELECT data_f INTO last_conf 
  FROM conferenza c JOIN tenuta t ON c.cod_conferenza = t.cod_conferenza 
  WHERE t.cod_sede = NEW.cod_sede 
  ORDER BY data_f DESC LIMIT 1;
  
  IF last_conf IS NULL OR NEW.data_i > last_conf THEN
    INSERT INTO tenuta (cod_conferenza, cod_sede) 
    VALUES (NEW.cod_conferenza, NEW.cod_sede);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_tenuta_trigger
AFTER INSERT ON conferenza
FOR EACH ROW
EXECUTE FUNCTION update_tenuta();


In questo caso, il trigger si attiva dopo l'inserimento di una nuova conferenza nella tabella "conferenza". La funzione "update_tenuta" viene eseguita per ogni riga inserita e cerca la data di fine dell'ultima conferenza tenuta nella stessa sede. Se la sede non ha ancora ospitato conferenze, la variabile "last_conf" è nulla. Se la data di inizio della nuova conferenza è successiva alla data di fine dell''ultima conferenza tenuta nella stessa sede, il trigger inserisce una nuova riga nella tabella "tenuta". Infine, la funzione restituisce la nuova riga inserita.



INSERT INTO sede (via, num_civico, luogo)
VALUES ('Viale Italia', 20, 'Roma');

INSERT INTO sede (via, num_civico, luogo)
VALUES ('Corso Europa', 5, 'Milano');

INSERT INTO sede (via, num_civico, luogo)
VALUES ('Piazza Garibaldi', 2, 'Napoli');

INSERT INTO sede (via, num_civico, luogo)
VALUES ('Strada degli Dei', 11, 'Firenze');

INSERT INTO sede (via, num_civico, luogo)
VALUES ('Viale Dante', 15, 'Bologna');

INSERT INTO sede (via, num_civico, luogo)
VALUES ('Corso Umberto', 1, 'Torino');

INSERT INTO sede (via, num_civico, luogo)
VALUES ('Piazza del Popolo', 7, 'Roma');

INSERT INTO sede (via, num_civico, luogo)
VALUES ('Via Veneto', 10, 'Roma');

INSERT INTO sede (via, num_civico, luogo)
VALUES ('Corso Vittorio', 17, 'Roma');

INSERT INTO sede (via, num_civico, luogo)
VALUES ('Strada dei Mille', 3, 'Napoli');

INSERT INTO comitato( tipo_c, nome_c)
	VALUES ('sc','Comitato Nazionale per la Bioetica');
	
INSERT INTO comitato( tipo_c, nome_c)
	VALUES ('lo','comitato per la rivitalizzazione del quartiere');

INSERT INTO comitato( tipo_c, nome_c)
	VALUES ('sc','Comitato Cambiamenti Climatici');
	
INSERT INTO comitato( tipo_c, nome_c)
	VALUES ('lo','comitato per la sicurezza della comunita');

INSERT INTO comitato( tipo_c, nome_c)
	VALUES ('sc','Comitato Consultivo per la Ricerca');
	
INSERT INTO comitato( tipo_c, nome_c)
	VALUES ('lo','gruppo per la tutela dell'' ambiente locale');

INSERT INTO comitato( tipo_c, nome_c)
	VALUES ('sc','Comitato per Etica in Ricerca');

INSERT INTO comitato( tipo_c, nome_c)
	VALUES ('lo','comitato per la sicurezza della comunita');

INSERT INTO comitato( tipo_c, nome_c)
	VALUES ('sc','Comitato per la Valutazione');

INSERT INTO comitato( tipo_c, nome_c)
	VALUES ('lo','comitato per l sviluppo delle attivita culturali del territorio');
    
insert into partecipante (nome, num_civico, cognome, email, titolo, istituzione) 
values ('Luca', 12, 'Rossi', 'luca.rossi@gmail.com', 'Dottore', 'Università');
insert into partecipante (nome, num_civico, cognome, email, titolo, istituzione) 
values ('Mario', 15, 'Bianchi', 'mario.bianchi@gmail.com', 'Professore', 'Scuola');
insert into partecipante (nome, num_civico, cognome, email, titolo, istituzione)
values ('Chiara', 20, 'Verdi', 'chiara.verdi@gmail.com', 'Dottoressa', 'Ospedale');
insert into partecipante (nome, num_civico, cognome, email, titolo, istituzione)
values ('Luca', 12, 'Rossi', 'luca.rossi@gmail.com', 'Dottore', 'Università');
insert into partecipante (nome, num_civico, cognome, email, titolo, istituzione) 
values ('Mario', 15, 'Bianchi', 'mario.bianchi@gmail.com', 'Professore', 'Scuola');
insert into partecipante (nome, num_civico, cognome, email, titolo, istituzione) 
values ('Chiara', 20, 'Verdi', 'chiara.verdi@gmail.com', 'Dottoressa', 'Ospedale');
insert into partecipante (nome, num_civico, cognome, email, titolo, istituzione) 
values ('Giovanni', 8, 'Neri', 'giovanni.neri@gmail.com', 'Ingegnere', 'Impresa');
insert into partecipante (nome, num_civico, cognome, email, titolo, istituzione)
values ('Paola', 5, 'Bianchetti', 'paola.bianchetti@gmail.com', 'Architetto', 'Studio');
insert into partecipante (nome, num_civico, cognome, email, titolo, istituzione) 
values ('Stefano', 2, 'Rizzo', 'stefano.rizzo@gmail.com', 'Avvocato', 'Studio Legale');
insert into partecipante (nome, num_civico, cognome, email, titolo, istituzione) 
values ('Gianluca', 17, 'Moretti', 'gianluca.moretti@gmail.com', 'Economista', 'Banca');
insert into partecipante (nome, num_civico, cognome, email, titolo, istituzione) 
values ('Marta', 19, 'Romano', 'marta.romano@gmail.com', 'Psicologa', 'Centro Sanitario');
insert into partecipante (nome, num_civico, cognome, email, titolo, istituzione) 
values ('Roberto', 11, 'Ferrari', 'roberto.ferrari@gmail.com', 'Medico', 'Ospedale');
insert into partecipante (nome, num_civico, cognome, email, titolo, istituzione) 
values ('Elena', 14, 'Esposito', 'elena.esposito@gmail.com', 'Infermiera', 'Ospedale');

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ('Mario', 12, 'Rossi', 'mario.rossi@email.it', 'Professore', 'Università', 1);

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ('Giovanni', 22, 'D''errico', 'giovanni.errico@email.it', 'Ingegnere', 'Azienda', 2);

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ('Luca', 33, 'Di Gennaro', 'luca.DiGennaro@hotmail.it', 'Medico', 'Ospedale', 1);

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ('Simone', 44, 'Neri', 'simone.neri@icloud.com', 'Avvocato', 'Studio Legale', 7);

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ('Alessandro', 55, 'Bianchi', 'alessandro.bianchi@email.com', 'Architetto', 'Studi Architettura', 5);

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ('Andrea', 66, 'Anastasio', 'andrea.anastasio@ig.it', 'Dottore Commercialista', 'Studio Commerciale', 9);

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ('Claudio', 77, 'Verdi', 'claudio.verdi@engine.com', 'Dottore in Informatica', 'Azienda Informatica', 7);

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ('Fabio', 88, 'Orlando', 'fabio.Orlando@email.it', 'Economista', 'Università', 9);

INSERT INTO organizzatore ( nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ( 'Anna', 25, 'niola', 'anna.niola@gmail.com', 'Architetto', 'Studio', 4);

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ( 'Chiara', 5, 'empoli', 'chiara.empoli@gmail.com', 'Operaio', 'Studio Legale', 4);

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ( 'lorenzo', 18, 'Blu', 'lorenzo.blu@email.it', 'Operaio', 'Ospedale', 3);

INSERT INTO organizzatore ( nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ( 'vitale', 7, 'Agrillo', 'VItale.Agrillo@email.com', 'Operaio specifico', 'Azienda', 3);

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ('Giuseppe', 77, 'sindoni', 'Giuseppe.sindoni@engine.com', ' Informatico', 'Azienda Informatica', 6);

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ('Giulio', 88, 'Pianese', 'Giulio.Pianese@email.it', 'Informatico', 'Università', 6);

INSERT INTO organizzatore ( nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ( 'Aurora', 25, 'bortolon', 'Aurora.bortolon@gmail.com', 'Architetto', 'Studio', 8);

INSERT INTO organizzatore ( nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ( 'Sofia', 5, 'Giorgi', 'Sofia.Giorgi@gmail.com', 'Animatrice', 'Studio Legale', 8);

INSERT INTO organizzatore ( nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ( 'Salvatore', 18, 'Monti', 'Salvatore.Monti@email.it', 'Fotografo', 'Ospedale', 10);

INSERT INTO organizzatore ( nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ( 'Luca', 7, 'Cardone', 'Luca.Cardone@email.com', 'Ingegnere informatico', 'Azienda', 10);

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ('Barbara', 77, 'effi', 'Barbara.effi@engine.com', 'estetista', 'Azienda Informatica', 2);

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ('Gennaro', 88, 'Giordano', 'Gennaro.Giordano@email.it', 'fioraio', 'Università', 3);

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ( 'Gianni', 25, 'Di Marzo', 'gianni.dimarzo@gmail.com', 'Allevatore', 'Studio', 6);

INSERT INTO organizzatore (nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ('Giorgio', 5, 'Di Giorgi', 'giorgio.giorgi@gmail.com', 'Operaio', 'Studio edile', 9);

INSERT INTO organizzatore ( nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ( 'Francesco', 18, 'Franco', 'Fracesco.Franco@email.it', 'Operaio', 'Ospedale', 1);

INSERT INTO organizzatore ( nome, num_civico, cognome, email, titolo, istituzione, cod_comitato)
VALUES ( 'vitale', 7, 'Agrillo', 'VItale.Agrillo@email.com', 'Operaio specifico', 'Azienda', 4);

insert into conferenza (sponsor, descrizione, ente, spesa, data_i, data_f, cod_sede) values
('Microsoft', 'Conference on AI and its future', 'AI Society', 5000, '2023-06-01', '2023-06-03', 1);

insert into conferenza (sponsor, descrizione, ente, spesa, data_i, data_f, cod_sede) values
('Apple', 'Latest innovations in technology', 'Tech Innovators', 6000, '2023-07-05', '2023-07-07', 2);

insert into conferenza (sponsor, descrizione, ente, spesa, data_i, data_f, cod_sede) values
('Google', 'Emerging trends in search engines', 'Search Engine Association', 4000, '2023-08-10', '2023-08-12', 3);

insert into conferenza (sponsor, descrizione, ente, spesa, data_i, data_f, cod_sede) values
('Facebook', 'Future of social media', 'Social Media Innovators', 3000, '2023-09-15', '2023-09-17', 4);

insert into conferenza (sponsor, descrizione, ente, spesa, data_i, data_f, cod_sede) values
('Amazon', 'Innovations in e-commerce', 'E-commerce Society', 8000, '2023-10-01', '2023-10-03', 5);

INSERT INTO sessione (data_prestabilita, orario_predefinito, cod_conferenza, cod_coordinatore)
VALUES ('2023-01-01', '10:00:00', 1, 2);

INSERT INTO sessione (data_prestabilita, orario_predefinito, cod_conferenza, cod_coordinatore)
VALUES ('2023-02-14', '14:30:00', 1, 3);

INSERT INTO sessione (data_prestabilita, orario_predefinito, cod_conferenza, cod_coordinatore)
VALUES ('2023-03-07', '09:00:00', 2, 7);

INSERT INTO sessione (data_prestabilita, orario_predefinito, cod_conferenza, cod_coordinatore)
VALUES ('2023-04-18', '11:45:00', 3, 9);

INSERT INTO sessione (data_prestabilita, orario_predefinito, cod_conferenza, cod_coordinatore)
VALUES ('2023-05-03', '15:15:00', 3, 3);

INSERT INTO sessione (data_prestabilita, orario_predefinito, cod_conferenza, cod_coordinatore)
VALUES ('2023-06-10', '10:30:00', 5, 6);

INSERT INTO sessione (data_prestabilita, orario_predefinito, cod_conferenza, cod_coordinatore)
VALUES ('2023-07-22', '14:00:00', 4, 8);


INSERT INTO sessione (data_prestabilita, orario_predefinito, cod_conferenza, cod_coordinatore)
VALUES ('2024-03-27', '10:45:00', 4, 4);

INSERT INTO sessione (data_prestabilita, orario_predefinito, cod_conferenza, cod_coordinatore)
VALUES ('2024-02-19', '14:15:00', 3, 4);

INSERT INTO sessione (data_prestabilita, orario_predefinito, cod_conferenza, cod_coordinatore)
VALUES ('2024-01-13', '09:30:00', 2, 9);

INSERT INTO sessione (data_prestabilita, orario_predefinito, cod_conferenza, cod_coordinatore)
VALUES ('2023-12-03', '13:45:00', 3, 9);

INSERT INTO sessione (data_prestabilita, orario_predefinito, cod_conferenza, cod_coordinatore)
VALUES ('2023-11-11', '10:00:00', 5, 2);

INSERT INTO sessione (data_prestabilita, orario_predefinito, cod_conferenza, cod_coordinatore)
VALUES ('2023-10-22', '14:30:00', 5, 2);

INSERT INTO sessione (data_prestabilita, orario_predefinito, cod_conferenza, cod_coordinatore)
VALUES ('2023-09-15', '11:00:00', 1, 10);

INSERT INTO intervento (abstract, cod_sessione)
VALUES ('Introduction to AI', 1);

INSERT INTO intervento (abstract, cod_sessione)
VALUES ('Advanced Database Design', 2);

INSERT INTO intervento (abstract, cod_sessione)
VALUES ('Machine Learning for Business', 2);

INSERT INTO intervento (abstract, cod_sessione)
VALUES ('Big Data Analytics', 7);

INSERT INTO intervento (abstract, cod_sessione)
VALUES ('Blockchain Technology and Cryptocurrencies', 8);

INSERT INTO intervento (abstract, cod_sessione)
VALUES ('Artificial Neural Networks', 8);

INSERT INTO intervento (abstract, cod_sessione)
VALUES ('Internet of Things', 3);

INSERT INTO intervento (abstract, cod_sessione)
VALUES ('Cloud Computing and Security', 5);


INSERT INTO intervento (abstract, cod_sessione)
VALUES ('E-commerce Trends', 12);

INSERT INTO intervento (abstract, cod_sessione)
VALUES ('UI/UX Design Principles', 11);

INSERT INTO occasione_extra (tipo_evento_s, tipo_spazio_i, cod_sessione, descrizione)
VALUES ('si', '', 1, 'visita guidata');


INSERT INTO occasione_extra (tipo_evento_s, tipo_spazio_i, cod_sessione, descrizione)
VALUES ('', 'si', 3, 'Coffee break');


INSERT INTO occasione_extra (tipo_evento_s, tipo_spazio_i, cod_sessione, descrizione)
VALUES ('si', '', 3, 'stand aziendali');


INSERT INTO occasione_extra (tipo_evento_s, tipo_spazio_i, cod_sessione, descrizione)
VALUES ('si', '', 4, 'discorso di apertura');

INSERT INTO occasione_extra (tipo_evento_s, tipo_spazio_i, cod_sessione, descrizione)
VALUES ('', 'si', 5, 'cena scolastica');

INSERT INTO occasione_extra (tipo_evento_s, tipo_spazio_i, cod_sessione, descrizione)
VALUES ('', 'si', 6, 'coktail di benvenuto');


INSERT INTO occasione_extra (tipo_evento_s, tipo_spazio_i, cod_sessione, descrizione)
VALUES ('', 'si', 7, 'aperitivo');

INSERT INTO occasione_extra (tipo_evento_s, tipo_spazio_i, cod_sessione, descrizione)
VALUES ('si', '', 8, 'fuochi d''artificio');

INSERT INTO occasione_extra (tipo_evento_s, tipo_spazio_i, cod_sessione, descrizione)
VALUES ('si', '', 9, 'corso di limbo');

INSERT INTO occasione_extra (tipo_evento_s, tipo_spazio_i, cod_sessione, descrizione)
VALUES ('', 'si', 5, 'cena di gruppo');

INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (1, 1, 'No', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (1, 2, 'No', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (1, 8, 'Si', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (1, 12, 'No', 'Si');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (2, 10, 'No', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (2, 6, 'Si', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (2, 7, 'Si', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (2, 9, 'No', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (2, 13, 'No', 'Si');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (3, 4, 'No', 'No');

INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (1, 5, 'Sì', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (2, 7, 'No', 'Sì');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (3, 12, 'Sì', 'Sì');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (4, 8, 'No', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (5, 15, 'Sì', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (6, 10, 'No', 'Sì');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (7, 18, 'Sì', 'Sì');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (8, 21, 'No', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (9, 26, 'Sì', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (10, 32, 'No', 'Sì');

INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (7, 5, 'NO', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (7, 7, 'No', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (8, 12, 'Sì', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (8, 8, 'No', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (9, 1, 'Sì', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (9, 2, 'No', 'Sì');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (10, 3, 'No', 'NO');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (10, 4, 'No', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (11, 5, 'Sì', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (11, 6, 'No', 'No');

INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (12, 7, 'No', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (12, 8, 'No', 'Sì');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (13, 10, 'No', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (13, 11, 'No', 'Si');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (6, 12, 'No', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (7, 13, 'No', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (8, 1, 'Sì', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (9, 3, 'No', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (10, 5, 'Sì', 'No');
INSERT INTO ammissione (cod_sessione, cod_partecipante, partecipante_s, keyonote_speaker) VALUES (11, 8, 'No', 'No');

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (1, 1);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (1, 2);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (1, 6);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (1, 8);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (2, 3);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (2, 4);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (2, 10);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (2, 11);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (3, 10);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (3, 12);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (3, 14);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (3, 16);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (4, 20);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (4, 24);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (4, 23);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (4, 17);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (5, 3);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (5, 18);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (5, 20);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (5, 22);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (2, 13);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (3, 22);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (1, 9);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (4, 11);

INSERT INTO gestione (cod_conferenza, cod_organizzatore)
VALUES (5, 24);

INSERT INTO tenuta (cod_conferenza, cod_sede) VALUES (1, 5);
INSERT INTO tenuta (cod_conferenza, cod_sede) VALUES (1, 4);
INSERT INTO tenuta (cod_conferenza, cod_sede) VALUES (1, 3);
INSERT INTO tenuta (cod_conferenza, cod_sede) VALUES (2, 4);
INSERT INTO tenuta (cod_conferenza, cod_sede) VALUES (2, 2);
INSERT INTO tenuta (cod_conferenza, cod_sede) VALUES (3, 1);
INSERT INTO tenuta (cod_conferenza, cod_sede) VALUES (3, 7);
INSERT INTO tenuta (cod_conferenza, cod_sede) VALUES (3, 8);
INSERT INTO tenuta (cod_conferenza, cod_sede) VALUES (4, 10);
INSERT INTO tenuta (cod_conferenza, cod_sede) VALUES (5, 9);
INSERT INTO tenuta (cod_conferenza, cod_sede) VALUES (5, 2);




CREATE OR REPLACE FUNCTION insert_sede(
    in_via varchar(30),
    in_num_civico int,
    in_luogo varchar(30)
) RETURNS void AS $$
BEGIN
    -- Verifica che non esista già una sede con la stessa combinazione di via, num_civico e luogo
    IF EXISTS (SELECT 1 FROM sede WHERE via = in_via AND num_civico = in_num_civico AND luogo = in_luogo) THEN
        RAISE EXCEPTION 'Esiste già una sede con la stessa via, numero civico e luogo';
    END IF;

    -- Inserimento della nuova sede
    INSERT INTO sede(via, num_civico, luogo) VALUES (in_via, in_num_civico, in_luogo);
END;
$$ LANGUAGE plpgsql;


Per utilizzare la funzione, basta chiamarla passando i valori desiderati per via, num_civico e luogo:

SELECT insert_sede('Via Roma', 123, 'Milano');



CREATE OR REPLACE FUNCTION calcola_spese_conferenza(cod_conf INTEGER)
RETURNS INTEGER AS $$
DECLARE
    totale_spese INTEGER;
BEGIN
    SELECT COALESCE(SUM(conferenza.spesa + occasione_extra.spesa_extra), 0)
    INTO totale_spese
    FROM conferenza
    LEFT JOIN occasione_extra
        ON conferenza.cod_conferenza = occasione_extra.cod_conferenza
    WHERE conferenza.cod_conferenza = cod_conf;
    
    RETURN totale_spese;
END;
$$ LANGUAGE plpgsql;
La funzione prende in input il codice della conferenza di cui si vuole calcolare il totale delle spese. Utilizza una clausola SELECT per sommare la spesa della conferenza e delle eventuali spese extra, utilizzando una LEFT JOIN per unire le due tabelle. Infine, restituisce il totale delle spese calcolato.

SELECT calcola_spese_conferenza(1);


CREATE FUNCTION insert_partecipante(
    p_nome varchar(30), 
    p_cognome varchar(30), 
    p_num_civico int, 
    p_email varchar(30), 
    p_titolo varchar(30), 
    p_istituzione varchar(30)
) RETURNS integer AS $$
DECLARE
    v_cod_partecipante integer;
BEGIN
    INSERT INTO partecipante (nome, cognome, num_civico, email, titolo, istituzione)
    VALUES (p_nome, p_cognome, p_num_civico, p_email, p_titolo, p_istituzione)
    RETURNING cod_partecipante INTO v_cod_partecipante;
    RETURN v_cod_partecipante;
END;
$$ LANGUAGE plpgsql;



Ecco un esempio di funzione che restituisce una variabile piuttosto che una tabella. In questo caso la funzione prende in input il codice di una conferenza e restituisce il numero totale di partecipanti registrati a quella conferenza:

sql
Copy code
CREATE OR REPLACE FUNCTION numero_partecipanti(cod_conferenza integer)
RETURNS integer AS $$
DECLARE
    num_partecipanti integer;
BEGIN
    SELECT COUNT(*) INTO num_partecipanti
    FROM ammissione
    WHERE cod_sessione IN (
        SELECT cod_sessione
        FROM sessione
        WHERE cod_conferenza = cod_conferenza
    ) AND partecipante_s = 'S';
    
    RETURN num_partecipanti;
END;
$$ LANGUAGE plpgsql;
Questa funzione utilizza una subquery per ottenere tutti i codici di sessione associati alla conferenza specificata come input, quindi conta il numero di partecipanti registrati a ciascuna di queste sessioni che hanno lo status "S" (ovvero "partecipante") e restituisce la somma totale come output. Ad esempio, se chiamiamo la funzione passando il codice della conferenza 1:


SELECT numero_partecipanti(1);



Ecco una funzione che restituisce il coordinatore con il maggior numero di sessioni assegnate in una determinata conferenza:

sql
Copy code
CREATE OR REPLACE FUNCTION coordinatore_piu_attivo(cod_conf INTEGER)
RETURNS coordinatore AS $$
DECLARE
    coordinatore_piu_attivo coordinatore;
BEGIN
    SELECT c.cod_coordinatore, c.nome, c.cognome, c.data_n
    INTO coordinatore_piu_attivo
    FROM coordinatore c
    JOIN sessione s ON c.cod_coordinatore = s.cod_coordinatore
    WHERE s.cod_conferenza = cod_conf
    GROUP BY c.cod_coordinatore
    ORDER BY COUNT(s.cod_sessione) DESC
    LIMIT 1;

    RETURN coordinatore_piu_attivo;
END;
$$ LANGUAGE plpgsql;
Questa funzione accetta come argomento il codice di una conferenza e restituisce il coordinatore con il maggior numero di sessioni assegnate in quella conferenza. La funzione restituisce una singola riga contenente il codice del coordinatore, il nome, il cognome e la data di nascita, rappresentati dal tipo di dato coordinatore.

Per utilizzare questa funzione, è possibile eseguire una query SQL come questa:

sql
Copy code
SELECT coordinatore_piu_attivo(1);
dove 1 è il codice della conferenza desiderata.



Ecco una procedura più complessa che calcola la media delle età dei partecipanti per ciascuna conferenza, tenendo conto solo dei partecipanti che hanno un''email registrata:

CREATE OR REPLACE PROCEDURE calcola_media_eta_partecipanti_conferenza()
AS $$
DECLARE
    cur_conferenza CURSOR FOR SELECT cod_conferenza FROM conferenza;
    conferenza_record RECORD;
    partecipanti_record RECORD;
    media_eta_conferenza NUMERIC;
    totale_partecipanti INTEGER;
BEGIN
    CREATE TEMP TABLE result_table (cod_conferenza INTEGER, media_eta NUMERIC) ON COMMIT DROP;

    FOR conferenza_record IN cur_conferenza LOOP
        media_eta_conferenza := 0;
        totale_partecipanti := 0;

        FOR partecipanti_record IN SELECT * FROM partecipante WHERE email IS NOT NULL AND cod_conferenza = conferenza_record.cod_conferenza LOOP
            media_eta_conferenza := media_eta_conferenza + (extract(year from age(partecipanti_record.data_n)))::numeric;
            totale_partecipanti := totale_partecipanti + 1;
        END LOOP;

        IF totale_partecipanti > 0 THEN
            media_eta_conferenza := media_eta_conferenza / totale_partecipanti;
            INSERT INTO result_table (cod_conferenza, media_eta) VALUES (conferenza_record.cod_conferenza, media_eta_conferenza);
        END IF;
    END LOOP;

    SELECT * FROM result_table;
END;
$$ LANGUAGE plpgsql;

La procedura utilizza un cursore per iterare su tutte le conferenze presenti nella tabella conferenza, quindi per ogni conferenza viene calcolata la media delle età dei partecipanti che hanno un'email registrata. Questa media viene quindi inserita in una nuova riga della tabella restituita dalla procedura insieme al codice della conferenza corrispondente. La procedura utilizza anche una variabile totale_partecipanti per tenere traccia del numero di partecipanti con un'email registrata per ciascuna conferenza.


CREATE OR REPLACE PROCEDURE calcola_media_eta_partecipanti_conferenza(cod_conferenza INTEGER, OUT media_eta NUMERIC)
AS $$
BEGIN
    SELECT AVG(EXTRACT(year FROM AGE(data_n))) INTO media_eta
    FROM partecipante
    WHERE cod_conferenza = calcola_media_eta_partecipanti_conferenza.cod_conferenza AND email IS NOT NULL;
END;
$$ LANGUAGE plpgsql;


Ecco una procedura che prende in input il codice di una conferenza e stampa a video il numero totale di partecipanti registrati alla conferenza:

sql
Copy code
CREATE OR REPLACE PROCEDURE total_partecipanti_conferenza(IN cod_conf integer)
LANGUAGE plpgsql
AS $$
DECLARE
    total_partecipanti integer;
BEGIN
    SELECT COUNT(DISTINCT cod_partecipante)
    INTO total_partecipanti
    FROM ammissione
    JOIN sessione ON ammissione.cod_sessione = sessione.cod_sessione
    JOIN conferenza ON sessione.cod_conferenza = conferenza.cod_conferenza
    WHERE conferenza.cod_conferenza = cod_conf;
    
    RAISE NOTICE 'Il numero totale di partecipanti registrati alla conferenza % è: %', cod_conf, total_partecipanti;
END;
$$;
Questa procedura utilizza la tabella ammissione per contare il numero di partecipanti distinti registrati per la conferenza specificata tramite il parametro cod_conf. La procedura quindi utilizza la clausola RAISE NOTICE per stampare a video il risultato della query. Si noti che la procedura non restituisce alcun valore di output.



CREATE OR REPLACE PROCEDURE check_presenza(IN cod_partecipante INTEGER, IN cod_conf INTEGER, IN data_presenza DATE)
LANGUAGE plpgsql
AS $$
DECLARE
count_presenze INTEGER;
msg VARCHAR(100);
BEGIN
SELECT COUNT(*)
INTO count_presenze
FROM ammissione
JOIN sessione ON ammissione.cod_sessione = sessione.cod_sessione
JOIN conferenza ON sessione.cod_conferenza = conferenza.cod_conferenza
WHERE conferenza.cod_conferenza = cod_conf
AND ammissione.cod_partecipante = cod_partecipante
AND DATE(sessione.data_sessione) = DATE(data_presenza);

IF count_presenze = 0 THEN
    msg := 'Il partecipante ' || cod_partecipante || ' non risulta registrato alla conferenza ' || cod_conf || ' nella data ' || data_presenza;
ELSE
    msg := 'Il partecipante ' || cod_partecipante || ' risulta registrato alla conferenza ' || cod_conf || ' nella data ' || data_presenza;
END IF;

RAISE NOTICE '%', msg;
END;
$$;
Questa procedura prende in input tre parametri: cod_partecipante, cod_conf e data_presenza. Verifica se il partecipante identificato da cod_partecipante è stato registrato alla conferenza identificata da cod_conf nella data data_presenza, e genera un messaggio di output appropriato. Se il partecipante non è stato registrato, il messaggio indica la mancata presenza, altrimenti indica la presenza. Il messaggio di output viene generato con la funzione RAISE NOTICE.


CREATE OR REPLACE PROCEDURE conto_organizzatori_per_comitato (
    IN codice_comitato INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    organizzatori INTEGER;
BEGIN
    SELECT COUNT(*) INTO organizzatori
    FROM organizzatore
    WHERE cod_comitato = codice_comitato;
    
    RAISE NOTICE 'Il comitato con codice % ha % organizzatore/i.', codice_comitato, organizzatori;
END;
$$;
La procedura prende in input il codice di un comitato e conta quanti organizzatori appartengono a quel comitato tramite una query sulla tabella organizzatore. Successivamente, la procedura utilizza la funzione RAISE NOTICE per visualizzare un messaggio in output che comunica il numero di organizzatori trovati per il comitato indicato.