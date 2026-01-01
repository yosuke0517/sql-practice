-- Generated from SampleCode/SQL
-- CREATE TABLE + INSERT statements only

-- From Code1.sql
DROP TABLE IF EXISTS Shops;
CREATE TABLE Shops (
 shop_id    CHAR(5) NOT NULL,
 shop_name  VARCHAR(64),
 rating     INTEGER,
 area       VARCHAR(64),
   CONSTRAINT pk_shops PRIMARY KEY (shop_id));

INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00001', '○○商店', 3, '北海道');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00002', '△△商店', 5, '青森県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00003', '××商店', 4, '岩手県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00004', '□□商店', 5, '宮城県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00005', 'A商店', 5, '秋田県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00006', 'B商店', 4, '山形県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00007', 'C商店', 3, '福島県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00008', 'D商店', 1, '茨城県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00009', 'E商店', 3, '栃木県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00010', 'F商店', 4, '群馬県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00011', 'G商店', 2, '埼玉県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00012', 'H商店', 3, '千葉県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00013', 'I商店', 4, '東京都');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00014', 'J商店', 1, '神奈川県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00015', 'K商店', 5, '新潟県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00016', 'L商店', 2, '富山県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00017', 'M商店', 5, '石川県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00018', 'N商店', 4, '福井県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00019', 'O商店', 4, '山梨県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00020', 'P商店', 1, '長野県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00021', 'Q商店', 1, '岐阜県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00022', 'R商店', 3, '静岡県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00023', 'S商店', 3, '愛知県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00024', 'T商店', 4, '三重県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00025', 'U商店', 5, '滋賀県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00026', 'V商店', 4, '京都府');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00027', 'W商店', 5, '大阪府');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00028', 'X商店', 1, '兵庫県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00029', 'Y商店', 5, '奈良県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00030', 'Z商店', 5, '和歌山県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00031', 'AA商店', 5, '鳥取県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00032', 'BB商店', 5, '島根県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00033', 'CC商店', 2, '岡山県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00034', 'DD商店', 4, '広島県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00035', 'EE商店', 3, '山口県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00036', 'FF商店', 3, '徳島県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00037', 'GG商店', 2, '香川県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00038', 'HH商店', 4, '愛媛県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00039', 'II商店', 3, '高知県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00040', 'JJ商店', 1, '福岡県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00041', 'KK商店', 4, '佐賀県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00042', 'LL商店', 3, '長崎県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00043', 'MM商店', 5, '熊本県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00044', 'NN商店', 1, '大分県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00045', 'OO商店', 3, '宮崎県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00046', 'PP商店', 4, '鹿児島県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00047', 'QQ商店', 4, '沖縄県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00048', 'RR商店', 3, '北海道');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00049', 'SS商店', 5, '青森県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00050', 'TT商店', 5, '岩手県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00051', 'UU商店', 5, '宮城県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00052', 'VV商店', 3, '秋田県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00053', 'WW商店', 2, '山形県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00054', 'XX商店', 1, '福島県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00055', 'YY商店', 5, '茨城県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00056', 'ZZ商店', 2, '栃木県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00057', 'AAA商店', 4, '群馬県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00058', 'BBB商店', 3, '埼玉県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00059', 'CCC商店', 4, '千葉県');
INSERT INTO Shops (shop_id, shop_name, rating, area) VALUES ('00060', '☆☆商店', 1, '東京都');

DROP TABLE IF EXISTS Reservations;
CREATE TABLE Reservations (
 reserve_id    INTEGER  NOT NULL,
 shop_id       CHAR(5),
 reserve_name  VARCHAR(64),
   CONSTRAINT pk_reservations PRIMARY KEY (reserve_id));

INSERT INTO Reservations (reserve_id, shop_id, reserve_name) VALUES (1, '00001', 'Aさん');
INSERT INTO Reservations (reserve_id, shop_id, reserve_name) VALUES (2, '00002', 'Bさん');
INSERT INTO Reservations (reserve_id, shop_id, reserve_name) VALUES (3, '00003', 'Cさん');
INSERT INTO Reservations (reserve_id, shop_id, reserve_name) VALUES (4, '00004', 'Dさん');
INSERT INTO Reservations (reserve_id, shop_id, reserve_name) VALUES (5, '00005', 'Eさん');
INSERT INTO Reservations (reserve_id, shop_id, reserve_name) VALUES (6, '00005', 'Fさん');
INSERT INTO Reservations (reserve_id, shop_id, reserve_name) VALUES (7, '00006', 'Gさん');
INSERT INTO Reservations (reserve_id, shop_id, reserve_name) VALUES (8, '00006', 'Hさん');
INSERT INTO Reservations (reserve_id, shop_id, reserve_name) VALUES (9, '00007', 'Iさん');
INSERT INTO Reservations (reserve_id, shop_id, reserve_name) VALUES (10,'00010', 'Jさん');

-- From Code2.sql
DROP TABLE IF EXISTS Address;
CREATE TABLE Address
(name       VARCHAR(32) NOT NULL,
 phone_nbr  VARCHAR(32) ,
 address    VARCHAR(32) NOT NULL,
 sex        CHAR(4) NOT NULL,
 age        INTEGER NOT NULL,
 PRIMARY KEY (name));

INSERT INTO Address VALUES('小川',	'080-3333-XXXX',	'東京都',	'男',	30);
INSERT INTO Address VALUES('前田',	'090-0000-XXXX',	'東京都',	'女',	21);
INSERT INTO Address VALUES('森',	'090-2984-XXXX',	'東京都',	'男',	45);
INSERT INTO Address VALUES('林',	'080-3333-XXXX',	'福島県',	'男',	32);
INSERT INTO Address VALUES('井上',	NULL,	            	'福島県',	'女',	55);
INSERT INTO Address VALUES('佐々木',	'080-5848-XXXX',	'千葉県',	'女',	19);
INSERT INTO Address VALUES('松本',	NULL,	            	'千葉県',	'女',	20);
INSERT INTO Address VALUES('佐藤',	'090-1922-XXXX',	'三重県',	'女',	25);
INSERT INTO Address VALUES('鈴木',	'090-0001-XXXX',	'和歌山県',	'男',	32);

DROP TABLE IF EXISTS Address2;
CREATE TABLE Address2
(name       VARCHAR(32) NOT NULL,
 phone_nbr  VARCHAR(32) ,
 address    VARCHAR(32) NOT NULL,
 sex        CHAR(4) NOT NULL,
 age        INTEGER NOT NULL,
   PRIMARY KEY (name));

INSERT INTO Address2 VALUES('小川',	'080-3333-XXXX',	'東京都',	'男',	30);
INSERT INTO Address2 VALUES('林',	'080-3333-XXXX',	'福島県',	'男',	32);
INSERT INTO Address2 VALUES('武田',	NULL,			'福島県',	'男',	18);
INSERT INTO Address2 VALUES('斉藤',	'080-2367-XXXX',	'千葉県',	'女',	19);
INSERT INTO Address2 VALUES('上野',	NULL,			'千葉県',	'女',	20);
INSERT INTO Address2 VALUES('広田',	'090-0205-XXXX',	'三重県',	'男',	25);
