--
-- PostgreSQL database dump
--

-- Dumped from database version 16.0 (Debian 16.0-1.pgdg120+1)
-- Dumped by pg_dump version 16.0 (Debian 16.0-1.pgdg120+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: Transaction_Type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."Transaction_Type" AS ENUM (
    'DEBIT',
    'CREDIT'
);


ALTER TYPE public."Transaction_Type" OWNER TO postgres;

--
-- Name: get_leg_total_downlines_placement(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_leg_total_downlines_placement(in_uid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	
DECLARE
	totaldownlines INT;
BEGIN
	WITH RECURSIVE hierachy AS (
		SELECT
			id,
			relation_placement_id
		FROM
			public."User"
		WHERE
			relation_placement_id = in_uid
		UNION
			SELECT
				e.id,
				e.relation_placement_id
			FROM
				public."User" e
			INNER JOIN hierachy s ON s.id = e.relation_placement_id
	)
	SELECT COUNT(*) INTO totaldownlines FROM hierachy;
	
	RETURN totaldownlines;
END;
$$;


ALTER FUNCTION public.get_leg_total_downlines_placement(in_uid integer) OWNER TO postgres;

--
-- Name: get_leg_total_downlines_ref(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_leg_total_downlines_ref(in_uid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	
DECLARE
	totaldownlines INT;
BEGIN
	WITH RECURSIVE hierachy AS (
		SELECT
			id,
			relation_ref_id
		FROM
			public."User"
		WHERE
			relation_ref_id = in_uid
		UNION
			SELECT
				e.id,
				e.relation_ref_id
			FROM
				public."User" e
			INNER JOIN hierachy s ON s.id = e.relation_ref_id
	)
	SELECT COUNT(*) INTO totaldownlines FROM hierachy;
	
	RETURN totaldownlines;
END;
$$;


ALTER FUNCTION public.get_leg_total_downlines_ref(in_uid integer) OWNER TO postgres;

--
-- Name: get_next_placement_leg(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_next_placement_leg(in_uid integer) RETURNS TABLE(out_placement_uid integer, out_placement_positon integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
	head_legs int;
	cur_head_id int;
	head_leg_arr int[];
	new_leg int;
	leg_found bool := false;
	current_leg_uid int;
	place_leg int;
	f record;
	h record;
	current_leg int := 1;
BEGIN
	head_legs = 0;
	
-- 	PERFORM id FROM public."User" WHERE id = in_uid;
	
-- 	IF NOT FOUND THEN
-- 		RAISE EXCEPTION 'HEAD UID USER NOT FOUND';
-- 	END IF;
	
	head_leg_arr = array_append(head_leg_arr,in_uid);
	WHILE leg_found = false LOOP
		FOREACH new_leg IN ARRAY head_leg_arr LOOP
			head_leg_arr = array_remove(head_leg_arr, new_leg);
			cur_head_id = new_leg;
			head_legs = 0;
			--RAISE INFO 'head uid %', cur_head_id;
			--RAISE INFO 'a';
			SELECT COUNT(*) INTO head_legs FROM public."User" WHERE relation_placement_id = cur_head_id;
			--RAISE INFO 'head legs %', head_legs;
			IF head_legs = 0 THEN
				current_leg_uid = cur_head_id;
				place_leg = 1;
				leg_found = true;
				EXIT;
			ELSEIF head_legs = 1 THEN
				FOR f IN 
					SELECT placement_leg FROM public."User" WHERE relation_placement_id = cur_head_id
				LOOP
					IF f.placement_leg > 1 THEN
						--RAISE INFO 'c';
						current_leg_uid = cur_head_id;
						place_leg = 1;
						leg_found = true;
					ELSE
						--RAISE INFO 'd';
						current_leg_uid = cur_head_id;
						place_leg = 2;
						leg_found = true;
					END IF;	
				END LOOP;
				EXIT;
			ELSE
				FOR h IN 
					SELECT id FROM public."User" WHERE relation_placement_id = cur_head_id 
				LOOP
					head_leg_arr = array_append(head_leg_arr,h.id);
				END LOOP;
			END IF;
		END LOOP;
	END LOOP;
	
	RETURN QUERY SELECT current_leg_uid AS out_placement_uid, place_leg AS out_placement_positon;
END;

$$;


ALTER FUNCTION public.get_next_placement_leg(in_uid integer) OWNER TO postgres;

--
-- Name: is_group_downline_of_placement(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_group_downline_of_placement(in_uid integer, in_upline_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$

DECLARE
	out_result bool;
	keep_looking bool:= true;
	curr_uid int;
	search_upline_id int;
BEGIN
	PERFORM id FROM public."User" WHERE id = in_uid;
	
	IF NOT FOUND THEN
		RAISE EXCEPTION 'USER NOT FOUND';
	END IF;
	
	PERFORM id FROM public."User" WHERE id = in_upline_id;
	
	IF NOT FOUND THEN
		RAISE EXCEPTION 'UPLINE NOT FOUND';
	END IF;
	
	curr_uid = in_uid;
	
	WHILE curr_uid IS NOT NULL LOOP
		SELECT relation_placement_id INTO search_upline_id FROM public."User" WHERE id = curr_uid;
		
		IF search_upline_id IS null THEN
			keep_looking = false;
			out_result = false;
			EXIT;
		ELSEIF search_upline_id <> in_upline_id THEN
			curr_uid = search_upline_id;
		ELSEIF search_upline_id = in_upline_id THEN
			out_result = true;
			EXIT;
		END IF;
		
	END LOOP;
	RETURN out_result;
END
$$;


ALTER FUNCTION public.is_group_downline_of_placement(in_uid integer, in_upline_id integer) OWNER TO postgres;

--
-- Name: is_group_downline_of_ref(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_group_downline_of_ref(in_uid integer, in_upline_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$

DECLARE
	out_result bool;
	keep_looking bool:= true;
	curr_uid int;
	search_upline_id int;
BEGIN
	PERFORM id FROM public."User" WHERE id = in_uid;
	
	IF NOT FOUND THEN
		RAISE EXCEPTION 'USER NOT FOUND';
	END IF;
	
	PERFORM id FROM public."User" WHERE id = in_upline_id;
	
	IF NOT FOUND THEN
		RAISE EXCEPTION 'UPLINE NOT FOUND';
	END IF;
	
	curr_uid = in_uid;
	
	WHILE curr_uid IS NOT NULL LOOP
		SELECT relation_ref_id INTO search_upline_id FROM public."User" WHERE id = curr_uid;
		
		IF search_upline_id IS null THEN
			keep_looking = false;
			out_result = false;
			EXIT;
		ELSEIF search_upline_id <> in_upline_id THEN
			curr_uid = search_upline_id;
		ELSEIF search_upline_id = in_upline_id THEN
			out_result = true;
			EXIT;
		END IF;
		
	END LOOP;
	RETURN out_result;
END
$$;


ALTER FUNCTION public.is_group_downline_of_ref(in_uid integer, in_upline_id integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: Admin; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Admin" (
    id integer NOT NULL,
    username text NOT NULL,
    email text NOT NULL,
    status text NOT NULL,
    password text NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    priviledge text NOT NULL
);


ALTER TABLE public."Admin" OWNER TO postgres;

--
-- Name: Admin_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Admin_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Admin_id_seq" OWNER TO postgres;

--
-- Name: Admin_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Admin_id_seq" OWNED BY public."Admin".id;


--
-- Name: Commission; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Commission" (
    id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    comm_code_id integer NOT NULL,
    amount double precision NOT NULL,
    purchase_id integer NOT NULL
);


ALTER TABLE public."Commission" OWNER TO postgres;

--
-- Name: Commission_Code; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Commission_Code" (
    id integer NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    "desc" text NOT NULL
);


ALTER TABLE public."Commission_Code" OWNER TO postgres;

--
-- Name: Commission_Code_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Commission_Code_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Commission_Code_id_seq" OWNER TO postgres;

--
-- Name: Commission_Code_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Commission_Code_id_seq" OWNED BY public."Commission_Code".id;


--
-- Name: Commission_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Commission_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Commission_id_seq" OWNER TO postgres;

--
-- Name: Commission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Commission_id_seq" OWNED BY public."Commission".id;


--
-- Name: Package; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Package" (
    id integer NOT NULL,
    name text NOT NULL,
    status text NOT NULL,
    cost double precision NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


ALTER TABLE public."Package" OWNER TO postgres;

--
-- Name: Package_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Package_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Package_id_seq" OWNER TO postgres;

--
-- Name: Package_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Package_id_seq" OWNED BY public."Package".id;


--
-- Name: Profile; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Profile" (
    id integer NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    ic_no text NOT NULL,
    address text NOT NULL,
    country text NOT NULL,
    mobileno text NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


ALTER TABLE public."Profile" OWNER TO postgres;

--
-- Name: Profile_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Profile_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Profile_id_seq" OWNER TO postgres;

--
-- Name: Profile_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Profile_id_seq" OWNED BY public."Profile".id;


--
-- Name: Purchase; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Purchase" (
    id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status text NOT NULL,
    package_id integer NOT NULL
);


ALTER TABLE public."Purchase" OWNER TO postgres;

--
-- Name: Purchase_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Purchase_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Purchase_id_seq" OWNER TO postgres;

--
-- Name: Purchase_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Purchase_id_seq" OWNED BY public."Purchase".id;


--
-- Name: Token; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Token" (
    id text NOT NULL,
    token text NOT NULL,
    type text NOT NULL,
    used boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "expiredAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE public."Token" OWNER TO postgres;

--
-- Name: Transaction; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Transaction" (
    id integer NOT NULL,
    wallet_id integer NOT NULL,
    amount double precision NOT NULL,
    balance double precision NOT NULL,
    type public."Transaction_Type" NOT NULL,
    tcode_id integer NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


ALTER TABLE public."Transaction" OWNER TO postgres;

--
-- Name: Transaction_Code; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Transaction_Code" (
    id integer NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    "desc" text NOT NULL
);


ALTER TABLE public."Transaction_Code" OWNER TO postgres;

--
-- Name: Transaction_Code_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Transaction_Code_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Transaction_Code_id_seq" OWNER TO postgres;

--
-- Name: Transaction_Code_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Transaction_Code_id_seq" OWNED BY public."Transaction_Code".id;


--
-- Name: Transaction_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Transaction_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Transaction_id_seq" OWNER TO postgres;

--
-- Name: Transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Transaction_id_seq" OWNED BY public."Transaction".id;


--
-- Name: User; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."User" (
    id integer NOT NULL,
    username text NOT NULL,
    email text NOT NULL,
    status text NOT NULL,
    password text NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    relation_ref_id integer,
    relation_placement_id integer,
    placement_leg integer NOT NULL,
    password_changed_at timestamp(3) without time zone,
    password_reset_expires timestamp(3) without time zone,
    password_reset_token text
);


ALTER TABLE public."User" OWNER TO postgres;

--
-- Name: User_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."User_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."User_id_seq" OWNER TO postgres;

--
-- Name: User_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."User_id_seq" OWNED BY public."User".id;


--
-- Name: Wallet; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Wallet" (
    id integer NOT NULL,
    user_id integer NOT NULL,
    wallet_type_id integer NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    amount double precision NOT NULL
);


ALTER TABLE public."Wallet" OWNER TO postgres;

--
-- Name: Wallet_Type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Wallet_Type" (
    id integer NOT NULL,
    name text NOT NULL,
    status text NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


ALTER TABLE public."Wallet_Type" OWNER TO postgres;

--
-- Name: Wallet_Type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Wallet_Type_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Wallet_Type_id_seq" OWNER TO postgres;

--
-- Name: Wallet_Type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Wallet_Type_id_seq" OWNED BY public."Wallet_Type".id;


--
-- Name: Wallet_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Wallet_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Wallet_id_seq" OWNER TO postgres;

--
-- Name: Wallet_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Wallet_id_seq" OWNED BY public."Wallet".id;


--
-- Name: _prisma_migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public._prisma_migrations (
    id character varying(36) NOT NULL,
    checksum character varying(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name character varying(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL
);


ALTER TABLE public._prisma_migrations OWNER TO postgres;

--
-- Name: Admin id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Admin" ALTER COLUMN id SET DEFAULT nextval('public."Admin_id_seq"'::regclass);


--
-- Name: Commission id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Commission" ALTER COLUMN id SET DEFAULT nextval('public."Commission_id_seq"'::regclass);


--
-- Name: Commission_Code id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Commission_Code" ALTER COLUMN id SET DEFAULT nextval('public."Commission_Code_id_seq"'::regclass);


--
-- Name: Package id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Package" ALTER COLUMN id SET DEFAULT nextval('public."Package_id_seq"'::regclass);


--
-- Name: Profile id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Profile" ALTER COLUMN id SET DEFAULT nextval('public."Profile_id_seq"'::regclass);


--
-- Name: Purchase id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Purchase" ALTER COLUMN id SET DEFAULT nextval('public."Purchase_id_seq"'::regclass);


--
-- Name: Transaction id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Transaction" ALTER COLUMN id SET DEFAULT nextval('public."Transaction_id_seq"'::regclass);


--
-- Name: Transaction_Code id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Transaction_Code" ALTER COLUMN id SET DEFAULT nextval('public."Transaction_Code_id_seq"'::regclass);


--
-- Name: User id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User" ALTER COLUMN id SET DEFAULT nextval('public."User_id_seq"'::regclass);


--
-- Name: Wallet id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Wallet" ALTER COLUMN id SET DEFAULT nextval('public."Wallet_id_seq"'::regclass);


--
-- Name: Wallet_Type id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Wallet_Type" ALTER COLUMN id SET DEFAULT nextval('public."Wallet_Type_id_seq"'::regclass);


--
-- Data for Name: Admin; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Admin" (id, username, email, status, password, created_at, updated_at, priviledge) FROM stdin;
\.


--
-- Data for Name: Commission; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Commission" (id, user_id, created_at, updated_at, comm_code_id, amount, purchase_id) FROM stdin;
1	1	2023-11-23 12:43:14.198+00	2023-11-23 12:43:14.198+00	3	300	1
2	2	2023-11-23 12:43:14.198+00	2023-11-23 12:43:14.198+00	3	300	2
3	3	2023-11-23 12:43:14.198+00	2023-11-23 12:43:14.198+00	3	300	3
4	1	2023-11-23 12:43:14.198+00	2023-11-23 12:43:14.198+00	3	300	1
5	2	2023-11-23 12:43:14.198+00	2023-11-23 12:43:14.198+00	3	300	2
6	3	2023-11-23 12:43:14.198+00	2023-11-23 12:43:14.198+00	3	300	3
\.


--
-- Data for Name: Commission_Code; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Commission_Code" (id, created_at, updated_at, "desc") FROM stdin;
1	2023-11-23 12:42:58.872+00	2023-11-23 12:42:58.872+00	Referral Bonus
2	2023-11-23 12:42:58.872+00	2023-11-23 12:42:58.872+00	Pairing Bonus
3	2023-11-23 12:42:58.872+00	2023-11-23 12:42:58.872+00	Group Bonus
4	2023-11-23 12:42:58.872+00	2023-11-23 12:42:58.872+00	Matching Bonus
\.


--
-- Data for Name: Package; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Package" (id, name, status, cost, created_at, updated_at) FROM stdin;
1	Package 500	active	500	2023-11-23 12:42:58.881+00	2023-11-23 12:42:58.881+00
2	Package 1000	active	1000	2023-11-23 12:42:58.881+00	2023-11-23 12:42:58.881+00
3	Package 2000	active	2000	2023-11-23 12:42:58.881+00	2023-11-23 12:42:58.881+00
4	Package 3000	active	3000	2023-11-23 12:42:58.881+00	2023-11-23 12:42:58.881+00
\.


--
-- Data for Name: Profile; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Profile" (id, first_name, last_name, ic_no, address, country, mobileno, user_id, created_at, updated_at) FROM stdin;
1	alice	001	1133668899	338, Jalan Emas 56000	Malaysia	33668899	1	2023-11-23 12:42:58.889+00	2023-11-23 12:42:58.889+00
2	bob	002	2233668899	138, Jalan Emas 56000	Malaysia	233668899	2	2023-11-23 12:43:14.134+00	2023-11-23 12:43:14.134+00
3	tony	003	3333668899	638, Jalan Emas 56000	Malaysia	333668899	3	2023-11-23 12:43:14.17+00	2023-11-23 12:43:14.17+00
4	lisa	004	2233668899	138, Jalan Emas 56000	Malaysia	233668899	4	2023-11-25 04:17:44.723+00	2023-11-25 04:17:44.723+00
5	zoe	005	3333668899	638, Jalan Emas 56000	Malaysia	333668899	5	2023-11-25 04:17:44.811+00	2023-11-25 04:17:44.811+00
6	ella	006	123123888	123,Jalan 888, 89888	Singapore	8899665432	6	2023-11-25 07:08:07.799+00	2023-11-25 07:08:07.799+00
7	tina	007	123123888	123,Jalan 888, 89888	Singapore	8899665432	7	2023-11-26 07:25:45.766+00	2023-11-26 07:25:45.766+00
8	nina	008	123123123	123, mobile road  	malaysia  	123123123	9	2023-12-03 05:39:25.187+00	2023-12-03 05:39:25.187+00
\.


--
-- Data for Name: Purchase; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Purchase" (id, user_id, created_at, updated_at, status, package_id) FROM stdin;
1	1	2023-11-23 12:43:14.191+00	2023-11-23 12:43:14.191+00	active	1
2	2	2023-11-23 12:43:14.191+00	2023-11-23 12:43:14.191+00	active	2
3	3	2023-11-23 12:43:14.191+00	2023-11-23 12:43:14.191+00	active	3
4	1	2023-11-23 12:43:14.191+00	2023-11-23 12:43:14.191+00	active	1
5	2	2023-11-23 12:43:14.191+00	2023-11-23 12:43:14.191+00	active	2
6	3	2023-11-23 12:43:14.191+00	2023-11-23 12:43:14.191+00	active	3
7	1	2023-11-28 06:57:29.595+00	2023-11-28 06:57:29.595+00	active	2
8	7	2023-11-28 06:59:35.673+00	2023-11-28 06:59:35.673+00	active	4
9	1	2023-11-28 07:09:54.209+00	2023-11-28 07:09:54.209+00	active	4
10	1	2023-11-28 07:49:29.694+00	2023-11-28 07:49:29.694+00	active	1
11	1	2023-11-28 07:52:18.835+00	2023-11-28 07:52:18.835+00	active	1
12	1	2023-12-04 13:06:45.931+00	2023-12-04 13:06:45.931+00	active	1
13	1	2023-12-04 13:10:01.737+00	2023-12-04 13:10:01.737+00	active	1
14	1	2023-12-04 13:11:25.792+00	2023-12-04 13:11:25.792+00	active	1
15	1	2023-12-04 13:14:42.012+00	2023-12-04 13:14:42.012+00	active	1
16	1	2023-12-04 13:22:44.719+00	2023-12-04 13:22:44.719+00	active	1
17	1	2023-12-04 13:23:43.588+00	2023-12-04 13:23:43.588+00	active	1
18	1	2023-12-04 13:24:16.678+00	2023-12-04 13:24:16.678+00	active	1
19	1	2023-12-04 13:25:07.572+00	2023-12-04 13:25:07.572+00	active	1
20	1	2023-12-04 13:25:37.902+00	2023-12-04 13:25:37.902+00	active	1
21	1	2023-12-04 13:25:53.598+00	2023-12-04 13:25:53.598+00	active	1
22	1	2023-12-04 13:27:00.26+00	2023-12-04 13:27:00.26+00	active	1
23	1	2023-12-04 13:27:36.179+00	2023-12-04 13:27:36.179+00	active	1
24	1	2023-12-04 13:31:45.787+00	2023-12-04 13:31:45.787+00	active	1
25	1	2023-12-04 13:32:49.817+00	2023-12-04 13:32:49.817+00	active	1
26	1	2023-12-04 13:35:38.234+00	2023-12-04 13:35:38.234+00	active	1
27	1	2023-12-04 13:36:40.912+00	2023-12-04 13:36:40.912+00	active	1
28	1	2023-12-04 13:37:17.999+00	2023-12-04 13:37:17.999+00	active	1
29	1	2023-12-04 13:40:11.216+00	2023-12-04 13:40:11.216+00	active	1
30	1	2023-12-04 13:40:40.632+00	2023-12-04 13:40:40.632+00	active	1
31	1	2023-12-04 13:42:09.558+00	2023-12-04 13:42:09.558+00	active	1
32	1	2023-12-04 13:42:18.98+00	2023-12-04 13:42:18.98+00	active	1
33	1	2023-12-04 13:58:08.521+00	2023-12-04 13:58:08.521+00	active	1
\.


--
-- Data for Name: Token; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Token" (id, token, type, used, "createdAt", "expiredAt", user_id) FROM stdin;
clpp1ais40001ws3ob102jwka	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MSwiaWF0IjoxNzAxNTgwODI5LCJleHAiOjE3MDkzNTY4Mjl9.p74PqHJ-roNh9KENFtwXiq_GlG3kwKf_3oEjInoIk8s	authentication	f	2023-12-03 05:20:29.332	2024-12-24 05:20:29.33	1
clpp1aod00003ws3on8ke0hau	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MSwiaWF0IjoxNzAxNTgwODM2LCJleHAiOjE3MDkzNTY4MzZ9.qKHt6cS6sx7FHCF0F7L7TeUjk6tV22uGc8fFdgbx3Kw	authentication	f	2023-12-03 05:20:36.564	2024-12-24 05:20:36.562	1
clpp1ar7z0005ws3o8u0oi2i8	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MSwiaWF0IjoxNzAxNTgwODQwLCJleHAiOjE3MDkzNTY4NDB9.WiNPRQMR-KQEQP4_cPvgfjn4UGNAmv9J960wmEUB2xM	authentication	f	2023-12-03 05:20:40.271	2024-12-24 05:20:40.269	1
clpp1b6ir0001a3ocvj7ieeiq	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MSwiaWF0IjoxNzAxNTgwODYwLCJleHAiOjE3MDkzNTY4NjB9.8Dru70TQPBlAATJ9doIuuSWPSOav87b-gx_e77_Bc70	authentication	f	2023-12-03 05:21:00.099	2024-12-24 05:21:00.098	1
clpts62ss00018aiu7y3ccgbu	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MSwiaWF0IjoxNzAxODY3ODM2LCJleHAiOjE3MDk2NDM4MzZ9.wAy_ckQxT45h6jbNUE3faJYLO8LivpmQo1G3zivOrt0	authentication	f	2023-12-06 13:03:56.33	2025-10-20 13:03:56.329	1
\.


--
-- Data for Name: Transaction; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Transaction" (id, wallet_id, amount, balance, type, tcode_id, created_at, updated_at) FROM stdin;
1	3	1000	1000	CREDIT	1	2023-11-23 12:43:14.134+00	2023-11-23 12:43:14.134+00
2	4	1000	1000	CREDIT	3	2023-11-23 12:43:14.134+00	2023-11-23 12:43:14.134+00
3	5	1000	1000	CREDIT	2	2023-11-23 12:43:14.17+00	2023-11-23 12:43:14.17+00
4	6	1000	1000	CREDIT	3	2023-11-23 12:43:14.17+00	2023-11-23 12:43:14.17+00
5	7	1000	1000	CREDIT	1	2023-11-25 04:17:44.723+00	2023-11-25 04:17:44.723+00
6	8	1000	1000	CREDIT	3	2023-11-25 04:17:44.723+00	2023-11-25 04:17:44.723+00
7	9	1000	1000	CREDIT	2	2023-11-25 04:17:44.811+00	2023-11-25 04:17:44.811+00
8	10	1000	1000	CREDIT	3	2023-11-25 04:17:44.811+00	2023-11-25 04:17:44.811+00
13	3	10	10	CREDIT	3	2023-11-27 01:16:22.79+00	2023-11-27 01:16:22.79+00
14	2	10	4980	DEBIT	3	2023-11-27 01:17:02.993+00	2023-11-27 01:17:02.993+00
15	3	10	20	CREDIT	3	2023-11-27 01:17:03+00	2023-11-27 01:17:03+00
17	4	10	10	CREDIT	3	2023-11-27 01:31:55.614+00	2023-11-27 01:31:55.614+00
12	2	10	4990	CREDIT	3	2023-11-27 01:16:22.777+00	2023-11-27 01:16:22.777+00
19	4	10	20	CREDIT	3	2023-11-27 11:42:52.615+00	2023-11-27 11:42:52.615+00
20	4	10	10	DEBIT	3	2023-11-27 12:04:44.472+00	2023-11-27 12:04:44.472+00
21	4	10	20	CREDIT	3	2023-11-27 12:10:07.038+00	2023-11-27 12:10:07.038+00
22	1	10	970	DEBIT	3	2023-11-27 12:17:18.235+00	2023-11-27 12:17:18.235+00
23	4	10	30	CREDIT	3	2023-11-27 12:17:18.253+00	2023-11-27 12:17:18.253+00
24	4	10	40	CREDIT	3	2023-11-27 12:18:20.727+00	2023-11-27 12:18:20.727+00
25	1	10	960	DEBIT	3	2023-11-27 12:18:20.761+00	2023-11-27 12:18:20.761+00
26	1	10	950	DEBIT	3	2023-11-27 12:18:20.789+00	2023-11-27 12:18:20.789+00
27	4	10	50	CREDIT	3	2023-11-27 12:18:20.798+00	2023-11-27 12:18:20.798+00
28	1	10	940	DEBIT	3	2023-11-27 12:19:17.411+00	2023-11-27 12:19:17.411+00
29	4	10	60	CREDIT	3	2023-11-27 12:19:17.439+00	2023-11-27 12:19:17.439+00
30	4	10	70	CREDIT	3	2023-11-27 12:22:31.382+00	2023-11-27 12:22:31.382+00
31	1	10	930	DEBIT	3	2023-11-27 12:22:31.41+00	2023-11-27 12:22:31.41+00
32	1	10	920	DEBIT	3	2023-11-27 12:25:06.178+00	2023-11-27 12:25:06.178+00
33	4	10	80	CREDIT	3	2023-11-27 12:25:06.21+00	2023-11-27 12:25:06.21+00
34	4	10	90	CREDIT	3	2023-11-27 12:25:36.759+00	2023-11-27 12:25:36.759+00
36	1	10	900	DEBIT	3	2023-11-27 12:28:30.033+00	2023-11-27 12:28:30.033+00
37	4	10	100	CREDIT	3	2023-11-27 12:28:30.069+00	2023-11-27 12:28:30.069+00
38	1	10	890	DEBIT	3	2023-11-27 12:32:03.845+00	2023-11-27 12:32:03.845+00
39	4	10	110	CREDIT	3	2023-11-27 12:32:03.871+00	2023-11-27 12:32:03.871+00
40	1	10	880	DEBIT	3	2023-11-27 12:32:26.42+00	2023-11-27 12:32:26.42+00
41	4	10	120	CREDIT	3	2023-11-27 12:32:26.439+00	2023-11-27 12:32:26.439+00
42	1	10	870	DEBIT	3	2023-11-27 12:32:51.708+00	2023-11-27 12:32:51.708+00
43	4	10	130	CREDIT	3	2023-11-27 12:32:51.728+00	2023-11-27 12:32:51.728+00
44	4	10	140	CREDIT	3	2023-11-27 12:53:10.088+00	2023-11-27 12:53:10.088+00
46	4	10	150	CREDIT	3	2023-11-27 12:59:04.422+00	2023-11-27 12:59:04.422+00
47	2	500	4480	DEBIT	2	2023-11-28 07:49:29.657+00	2023-11-28 07:49:29.657+00
48	2	500	3980	DEBIT	2	2023-11-28 07:52:18.818+00	2023-11-28 07:52:18.818+00
49	2	500	3480	DEBIT	2	2023-12-04 13:06:45.829+00	2023-12-04 13:06:45.829+00
50	1	500	1360	DEBIT	2	2023-12-04 13:10:01.718+00	2023-12-04 13:10:01.718+00
51	1	500	860	DEBIT	2	2023-12-04 13:11:25.784+00	2023-12-04 13:11:25.784+00
52	2	500	2980	DEBIT	2	2023-12-04 13:14:41.995+00	2023-12-04 13:14:41.995+00
53	1	500	360	DEBIT	2	2023-12-04 13:22:44.704+00	2023-12-04 13:22:44.704+00
54	2	500	2480	DEBIT	2	2023-12-04 13:25:07.56+00	2023-12-04 13:25:07.56+00
55	2	500	1980	DEBIT	2	2023-12-04 13:25:37.895+00	2023-12-04 13:25:37.895+00
56	2	500	1480	DEBIT	2	2023-12-04 13:25:53.588+00	2023-12-04 13:25:53.588+00
57	2	500	980	DEBIT	2	2023-12-04 13:27:00.244+00	2023-12-04 13:27:00.244+00
58	2	500	480	DEBIT	2	2023-12-04 13:27:36.172+00	2023-12-04 13:27:36.172+00
59	2	500	47500	DEBIT	2	2023-12-04 13:42:09.546+00	2023-12-04 13:42:09.546+00
60	1	500	35500	DEBIT	2	2023-12-04 13:42:18.974+00	2023-12-04 13:42:18.974+00
61	2	500	47000	DEBIT	2	2023-12-04 13:58:08.505+00	2023-12-04 13:58:08.505+00
35	1	10	910	CREDIT	3	2023-11-27 12:25:36.791+00	2023-11-27 12:25:36.791+00
45	1	10	860	CREDIT	3	2023-11-27 12:59:04.401+00	2023-11-27 12:59:04.401+00
16	1	10	990	CREDIT	3	2023-11-27 01:31:55.597+00	2023-11-27 01:31:55.597+00
18	1	10	980	CREDIT	3	2023-11-27 11:42:52.583+00	2023-11-27 11:42:52.583+00
\.


--
-- Data for Name: Transaction_Code; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Transaction_Code" (id, created_at, updated_at, "desc") FROM stdin;
1	2023-11-23 12:42:58.861+00	2023-11-23 12:42:58.861+00	Transfer
2	2023-11-23 12:42:58.861+00	2023-11-23 12:42:58.861+00	Purchase
3	2023-11-23 12:42:58.861+00	2023-11-23 12:42:58.861+00	Commission
4	2023-11-23 12:42:58.861+00	2023-11-23 12:42:58.861+00	Withdrawal
\.


--
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."User" (id, username, email, status, password, created_at, updated_at, relation_ref_id, relation_placement_id, placement_leg, password_changed_at, password_reset_expires, password_reset_token) FROM stdin;
2	bob002	bob@mlmdev.com	normal	abc123	2023-11-23 12:43:14.134+00	2023-11-23 12:43:14.134+00	1	1	1	\N	\N	\N
3	tony003	tony@mlmdev.com	normal	abc123	2023-11-23 12:43:14.17+00	2023-11-23 12:43:14.17+00	1	1	2	\N	\N	\N
1	alice001	alice@alice.com	normal	abc123	2023-11-23 12:42:58.889+00	2023-11-24 05:12:01.066+00	\N	\N	0	\N	\N	\N
4	lisa004	lisa@mlmdev.com	normal	abc123	2023-11-25 04:17:44.723+00	2023-11-25 04:17:44.723+00	2	2	1	\N	\N	\N
5	zoe005	zoe@mlmdev.com	normal	abc123	2023-11-25 04:17:44.811+00	2023-11-25 04:17:44.811+00	1	3	2	\N	\N	\N
6	ella006	ella@ella.com	normal	ella1234	2023-11-25 07:08:07.799+00	2023-11-25 07:08:07.799+00	2	2	2	\N	\N	\N
7	tina007	tina@tina.com	normal	tina1234	2023-11-26 07:25:45.766+00	2023-11-26 07:25:45.766+00	5	5	1	\N	\N	\N
9	nina008	nina008@email.com	normal	abc123	2023-12-03 05:39:25.187+00	2023-12-03 05:39:25.187+00	1	3	1	\N	\N	\N
\.


--
-- Data for Name: Wallet; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Wallet" (id, user_id, wallet_type_id, created_at, updated_at, amount) FROM stdin;
5	3	2	2023-11-23 12:43:14.17+00	2023-11-23 12:43:14.17+00	0
6	3	1	2023-11-23 12:43:14.17+00	2023-11-23 12:43:14.17+00	1000
7	4	2	2023-11-25 04:17:44.723+00	2023-11-25 04:17:44.723+00	0
8	4	1	2023-11-25 04:17:44.723+00	2023-11-25 04:17:44.723+00	0
9	5	2	2023-11-25 04:17:44.811+00	2023-11-25 04:17:44.811+00	0
10	5	1	2023-11-25 04:17:44.811+00	2023-11-25 04:17:44.811+00	1000
11	6	1	2023-11-25 07:08:07.799+00	2023-11-25 07:08:07.799+00	0
12	6	2	2023-11-25 07:08:07.799+00	2023-11-25 07:08:07.799+00	0
13	7	1	2023-11-26 07:25:45.766+00	2023-11-26 07:25:45.766+00	0
14	7	2	2023-11-26 07:25:45.766+00	2023-11-26 07:25:45.766+00	0
1	1	1	2023-11-23 12:42:58.889+00	2023-12-04 13:42:18.974+00	35500
2	1	2	2023-11-23 12:42:58.889+00	2023-12-04 13:58:08.505+00	47000
3	2	2	2023-11-23 12:43:14.134+00	2023-11-27 01:17:02.986+00	20
4	2	1	2023-11-23 12:43:14.134+00	2023-11-27 12:59:04.422+00	150
15	9	1	2023-12-03 05:39:25.187+00	2023-12-03 05:39:25.187+00	0
16	9	2	2023-12-03 05:39:25.187+00	2023-12-03 05:39:25.187+00	0
\.


--
-- Data for Name: Wallet_Type; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Wallet_Type" (id, name, status, created_at, updated_at) FROM stdin;
1	epoint	active	2023-11-23 12:42:58.889+00	2023-11-23 12:42:58.889+00
2	ewallet	active	2023-11-23 12:42:58.889+00	2023-11-23 12:42:58.889+00
\.


--
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
5250a884-e06c-4cb1-9edd-71e654e991d6	a2f754c41d970f4751a201bb29e90d38520d87ba74299779d980e2efde5d8f24	2023-11-23 12:42:58.098845+00	20231123124257_init_migration	\N	\N	2023-11-23 12:42:57.785516+00	1
989ccb6e-d225-4400-ae09-fd3b3fec3c49	c1d0e977091c58d3add5253961ffb121961c151db62271ff7315b493a1a3a775	2023-11-26 01:30:17.182609+00	20231126013017_added_token_table	\N	\N	2023-11-26 01:30:17.053378+00	1
bdcbe59d-6cf3-4f73-be77-bc2faed4da63	ce2985bc816fdd3697cc6d1a3e7b9f0ccf11ffa224e69578bc4a335e910b138f	2023-11-26 02:21:22.659768+00	20231126022122_added_jwt_fields_to_user_table	\N	\N	2023-11-26 02:21:22.644153+00	1
\.


--
-- Name: Admin_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Admin_id_seq"', 1, false);


--
-- Name: Commission_Code_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Commission_Code_id_seq"', 4, true);


--
-- Name: Commission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Commission_id_seq"', 6, true);


--
-- Name: Package_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Package_id_seq"', 4, true);


--
-- Name: Profile_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Profile_id_seq"', 8, true);


--
-- Name: Purchase_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Purchase_id_seq"', 33, true);


--
-- Name: Transaction_Code_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Transaction_Code_id_seq"', 4, true);


--
-- Name: Transaction_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Transaction_id_seq"', 61, true);


--
-- Name: User_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."User_id_seq"', 9, true);


--
-- Name: Wallet_Type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Wallet_Type_id_seq"', 2, true);


--
-- Name: Wallet_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Wallet_id_seq"', 16, true);


--
-- Name: Admin Admin_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Admin"
    ADD CONSTRAINT "Admin_pkey" PRIMARY KEY (id);


--
-- Name: Commission_Code Commission_Code_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Commission_Code"
    ADD CONSTRAINT "Commission_Code_pkey" PRIMARY KEY (id);


--
-- Name: Commission Commission_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Commission"
    ADD CONSTRAINT "Commission_pkey" PRIMARY KEY (id);


--
-- Name: Package Package_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Package"
    ADD CONSTRAINT "Package_pkey" PRIMARY KEY (id);


--
-- Name: Profile Profile_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Profile"
    ADD CONSTRAINT "Profile_pkey" PRIMARY KEY (id);


--
-- Name: Purchase Purchase_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Purchase"
    ADD CONSTRAINT "Purchase_pkey" PRIMARY KEY (id);


--
-- Name: Token Token_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Token"
    ADD CONSTRAINT "Token_pkey" PRIMARY KEY (id);


--
-- Name: Transaction_Code Transaction_Code_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Transaction_Code"
    ADD CONSTRAINT "Transaction_Code_pkey" PRIMARY KEY (id);


--
-- Name: Transaction Transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Transaction"
    ADD CONSTRAINT "Transaction_pkey" PRIMARY KEY (id);


--
-- Name: User User_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (id);


--
-- Name: Wallet_Type Wallet_Type_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Wallet_Type"
    ADD CONSTRAINT "Wallet_Type_pkey" PRIMARY KEY (id);


--
-- Name: Wallet Wallet_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Wallet"
    ADD CONSTRAINT "Wallet_pkey" PRIMARY KEY (id);


--
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- Name: Admin_email_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "Admin_email_key" ON public."Admin" USING btree (email);


--
-- Name: Admin_username_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "Admin_username_key" ON public."Admin" USING btree (username);


--
-- Name: Profile_user_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "Profile_user_id_key" ON public."Profile" USING btree (user_id);


--
-- Name: Token_token_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "Token_token_key" ON public."Token" USING btree (token);


--
-- Name: User_email_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "User_email_key" ON public."User" USING btree (email);


--
-- Name: User_username_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "User_username_key" ON public."User" USING btree (username);


--
-- Name: Commission Commission_comm_code_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Commission"
    ADD CONSTRAINT "Commission_comm_code_id_fkey" FOREIGN KEY (comm_code_id) REFERENCES public."Commission_Code"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Commission Commission_purchase_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Commission"
    ADD CONSTRAINT "Commission_purchase_id_fkey" FOREIGN KEY (purchase_id) REFERENCES public."Purchase"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Commission Commission_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Commission"
    ADD CONSTRAINT "Commission_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Profile Profile_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Profile"
    ADD CONSTRAINT "Profile_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Purchase Purchase_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Purchase"
    ADD CONSTRAINT "Purchase_package_id_fkey" FOREIGN KEY (package_id) REFERENCES public."Package"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Purchase Purchase_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Purchase"
    ADD CONSTRAINT "Purchase_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Token Token_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Token"
    ADD CONSTRAINT "Token_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Transaction Transaction_tcode_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Transaction"
    ADD CONSTRAINT "Transaction_tcode_id_fkey" FOREIGN KEY (tcode_id) REFERENCES public."Transaction_Code"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Transaction Transaction_wallet_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Transaction"
    ADD CONSTRAINT "Transaction_wallet_id_fkey" FOREIGN KEY (wallet_id) REFERENCES public."Wallet"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: User User_relation_placement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_relation_placement_id_fkey" FOREIGN KEY (relation_placement_id) REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: User User_relation_ref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_relation_ref_id_fkey" FOREIGN KEY (relation_ref_id) REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: Wallet Wallet_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Wallet"
    ADD CONSTRAINT "Wallet_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Wallet Wallet_wallet_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Wallet"
    ADD CONSTRAINT "Wallet_wallet_type_id_fkey" FOREIGN KEY (wallet_type_id) REFERENCES public."Wallet_Type"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

