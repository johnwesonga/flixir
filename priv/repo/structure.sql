--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4 (Postgres.app)
-- Dumped by pg_dump version 16.4 (Postgres.app)

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: auth_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_sessions (
    id uuid NOT NULL,
    tmdb_session_id character varying(255) NOT NULL,
    tmdb_user_id integer NOT NULL,
    username character varying(255) NOT NULL,
    expires_at timestamp(0) without time zone NOT NULL,
    last_accessed_at timestamp(0) without time zone NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: user_movie_list_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_movie_list_items (
    id uuid NOT NULL,
    list_id uuid NOT NULL,
    tmdb_movie_id integer NOT NULL,
    added_at timestamp(0) without time zone NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: user_movie_lists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_movie_lists (
    id uuid NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    is_public boolean DEFAULT false NOT NULL,
    tmdb_user_id integer NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: auth_sessions auth_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_sessions
    ADD CONSTRAINT auth_sessions_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: user_movie_list_items user_movie_list_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_movie_list_items
    ADD CONSTRAINT user_movie_list_items_pkey PRIMARY KEY (id);


--
-- Name: user_movie_lists user_movie_lists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_movie_lists
    ADD CONSTRAINT user_movie_lists_pkey PRIMARY KEY (id);


--
-- Name: auth_sessions_expires_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_sessions_expires_at_index ON public.auth_sessions USING btree (expires_at);


--
-- Name: auth_sessions_tmdb_session_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX auth_sessions_tmdb_session_id_index ON public.auth_sessions USING btree (tmdb_session_id);


--
-- Name: auth_sessions_tmdb_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_sessions_tmdb_user_id_index ON public.auth_sessions USING btree (tmdb_user_id);


--
-- Name: idx_unique_movie_per_list; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_unique_movie_per_list ON public.user_movie_list_items USING btree (list_id, tmdb_movie_id);


--
-- Name: user_movie_list_items_added_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_movie_list_items_added_at_index ON public.user_movie_list_items USING btree (added_at);


--
-- Name: user_movie_list_items_list_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_movie_list_items_list_id_index ON public.user_movie_list_items USING btree (list_id);


--
-- Name: user_movie_list_items_tmdb_movie_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_movie_list_items_tmdb_movie_id_index ON public.user_movie_list_items USING btree (tmdb_movie_id);


--
-- Name: user_movie_lists_tmdb_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_movie_lists_tmdb_user_id_index ON public.user_movie_lists USING btree (tmdb_user_id);


--
-- Name: user_movie_lists_tmdb_user_id_updated_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_movie_lists_tmdb_user_id_updated_at_index ON public.user_movie_lists USING btree (tmdb_user_id, updated_at);


--
-- Name: user_movie_lists_updated_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_movie_lists_updated_at_index ON public.user_movie_lists USING btree (updated_at);


--
-- Name: user_movie_list_items user_movie_list_items_list_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_movie_list_items
    ADD CONSTRAINT user_movie_list_items_list_id_fkey FOREIGN KEY (list_id) REFERENCES public.user_movie_lists(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20250725214604);
INSERT INTO public."schema_migrations" (version) VALUES (20250804000040);
INSERT INTO public."schema_migrations" (version) VALUES (20250804000049);
