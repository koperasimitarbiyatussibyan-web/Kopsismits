-- KOPERASI SEKOLAH MI TARBIYATUSSIBYAN
-- Jalankan seluruh file ini di Supabase Dashboard > SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.profiles (id uuid primary key references auth.users(id) on delete cascade,email text,role text not null default 'cashier' check (role in ('admin','cashier')),created_at timestamptz not null default now());
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$ begin insert into public.profiles(id,email,role) values(new.id,new.email,'cashier') on conflict(id) do update set email=excluded.email; return new; end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
create table if not exists public.products (id uuid primary key default gen_random_uuid(),name text not null,sku text unique,category text not null default 'Lainnya',unit text not null default 'pcs',cost_price numeric(14,2) not null default 0 check(cost_price>=0),sell_price numeric(14,2) not null default 0 check(sell_price>=0),stock integer not null default 0 check(stock>=0),min_stock integer not null default 0 check(min_stock>=0),created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.sales (id uuid primary key default gen_random_uuid(),receipt_no text not null unique,cashier_id uuid not null references auth.users(id),payment_method text not null default 'Tunai',total numeric(14,2) not null check(total>=0),paid_amount numeric(14,2) not null check(paid_amount>=total),change_amount numeric(14,2) not null default 0 check(change_amount>=0),created_at timestamptz not null default now(),voided_at timestamptz,void_reason text);
create table if not exists public.sale_items (id uuid primary key default gen_random_uuid(),sale_id uuid not null references public.sales(id) on delete cascade,product_id uuid references public.products(id) on delete set null,product_name text not null,quantity integer not null check(quantity>0),unit_price numeric(14,2) not null check(unit_price>=0),unit_cost numeric(14,2) not null check(unit_cost>=0),subtotal numeric(14,2) not null check(subtotal>=0));
create table if not exists public.expenses (id uuid primary key default gen_random_uuid(),title text not null,amount numeric(14,2) not null check(amount>0),expense_date date not null default current_date,created_by uuid not null default auth.uid() references auth.users(id),created_at timestamptz not null default now());
create table if not exists public.stock_movements (id uuid primary key default gen_random_uuid(),product_id uuid references public.products(id) on delete set null,product_name text not null,movement_type text not null check(movement_type in ('initial','sale','restock','adjustment','damage','return')),quantity_change integer not null,stock_after integer not null check(stock_after>=0),note text,reference_id uuid,created_by uuid default auth.uid() references auth.users(id),created_at timestamptz not null default now());
create or replace function public.current_user_role() returns text language sql stable security definer set search_path=public as $$ select role from public.profiles where id=auth.uid() limit 1; $$;

alter table public.profiles enable row level security; alter table public.products enable row level security; alter table public.sales enable row level security; alter table public.sale_items enable row level security; alter table public.expenses enable row level security; alter table public.stock_movements enable row level security;
drop policy if exists "profile read self or admin" on public.profiles; create policy "profile read self or admin" on public.profiles for select to authenticated using(id=auth.uid() or public.current_user_role()='admin');
drop policy if exists "admin manage profiles" on public.profiles; create policy "admin manage profiles" on public.profiles for update to authenticated using(public.current_user_role()='admin') with check(public.current_user_role()='admin');
drop policy if exists "authenticated read products" on public.products; create policy "authenticated read products" on public.products for select to authenticated using(true);
drop policy if exists "admin insert products" on public.products; create policy "admin insert products" on public.products for insert to authenticated with check(public.current_user_role()='admin');
drop policy if exists "admin update products" on public.products; create policy "admin update products" on public.products for update to authenticated using(public.current_user_role()='admin') with check(public.current_user_role()='admin');
drop policy if exists "admin delete products" on public.products; create policy "admin delete products" on public.products for delete to authenticated using(public.current_user_role()='admin');
drop policy if exists "authenticated read sales" on public.sales; create policy "authenticated read sales" on public.sales for select to authenticated using(true);
drop policy if exists "authenticated read sale items" on public.sale_items; create policy "authenticated read sale items" on public.sale_items for select to authenticated using(true);
drop policy if exists "admin read expenses" on public.expenses; create policy "admin read expenses" on public.expenses for select to authenticated using(public.current_user_role()='admin');
drop policy if exists "admin insert expenses" on public.expenses; create policy "admin insert expenses" on public.expenses for insert to authenticated with check(public.current_user_role()='admin');
drop policy if exists "admin read stock movements" on public.stock_movements; create policy "admin read stock movements" on public.stock_movements for select to authenticated using(public.current_user_role()='admin');

create or replace function public.checkout_sale(p_payment_method text,p_paid_amount numeric,p_items jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_sale_id uuid:=gen_random_uuid(); v_receipt text; v_total numeric(14,2):=0; v_item jsonb; v_product public.products%rowtype; v_qty integer; v_change numeric(14,2); v_sale public.sales%rowtype;
begin
 if auth.uid() is null then raise exception 'Silakan login terlebih dahulu.'; end if;
 if public.current_user_role() not in ('admin','cashier') then raise exception 'Akun tidak memiliki izin transaksi.'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Keranjang masih kosong.'; end if;
 if p_payment_method not in ('Tunai','Transfer','QRIS') then raise exception 'Metode pembayaran tidak valid.'; end if;
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_qty:=(v_item->>'quantity')::integer; if v_qty is null or v_qty<=0 then raise exception 'Jumlah barang harus lebih dari nol.'; end if;
  select * into v_product from public.products where id=(v_item->>'product_id')::uuid for update;
  if not found then raise exception 'Barang tidak ditemukan.'; end if;
  if v_product.stock<v_qty then raise exception 'Stok % tidak mencukupi. Stok tersedia: %',v_product.name,v_product.stock; end if;
  v_total:=v_total+v_product.sell_price*v_qty;
 end loop;
 if p_paid_amount is null or p_paid_amount<v_total then raise exception 'Pembayaran kurang dari total belanja (%).',v_total; end if;
 v_change:=p_paid_amount-v_total; v_receipt:='KMT-'||to_char(now(),'YYYYMMDD-HH24MISS')||'-'||upper(substr(replace(v_sale_id::text,'-',''),1,6));
 insert into public.sales(id,receipt_no,cashier_id,payment_method,total,paid_amount,change_amount) values(v_sale_id,v_receipt,auth.uid(),p_payment_method,v_total,p_paid_amount,v_change) returning * into v_sale;
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_qty:=(v_item->>'quantity')::integer; select * into v_product from public.products where id=(v_item->>'product_id')::uuid for update;
  if v_product.stock<v_qty then raise exception 'Stok % berubah dan tidak mencukupi.',v_product.name; end if;
  insert into public.sale_items(sale_id,product_id,product_name,quantity,unit_price,unit_cost,subtotal) values(v_sale_id,v_product.id,v_product.name,v_qty,v_product.sell_price,v_product.cost_price,v_product.sell_price*v_qty);
  update public.products set stock=stock-v_qty,updated_at=now() where id=v_product.id;
  insert into public.stock_movements(product_id,product_name,movement_type,quantity_change,stock_after,note,reference_id,created_by) values(v_product.id,v_product.name,'sale',-v_qty,v_product.stock-v_qty,'Penjualan '||v_receipt,v_sale_id,auth.uid());
 end loop;
 return jsonb_build_object('id',v_sale.id,'receipt_no',v_sale.receipt_no,'cashier_id',v_sale.cashier_id,'payment_method',v_sale.payment_method,'total',v_sale.total,'paid_amount',v_sale.paid_amount,'change_amount',v_sale.change_amount,'created_at',v_sale.created_at);
end; $$;
revoke all on function public.checkout_sale(text,numeric,jsonb) from public; grant execute on function public.checkout_sale(text,numeric,jsonb) to authenticated;
create or replace function public.adjust_stock(p_product_id uuid,p_quantity_change integer,p_movement_type text,p_note text default null) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_product public.products%rowtype; v_new integer;
begin
 if auth.uid() is null or public.current_user_role()<>'admin' then raise exception 'Hanya admin yang dapat menyesuaikan stok.'; end if;
 if p_quantity_change=0 then raise exception 'Perubahan stok tidak boleh nol.'; end if;
 if p_movement_type not in ('restock','adjustment','damage','return','initial') then raise exception 'Jenis pergerakan stok tidak valid.'; end if;
 select * into v_product from public.products where id=p_product_id for update; if not found then raise exception 'Barang tidak ditemukan.'; end if;
 v_new:=v_product.stock+p_quantity_change; if v_new<0 then raise exception 'Stok tidak boleh negatif.'; end if;
 update public.products set stock=v_new,updated_at=now() where id=p_product_id;
 insert into public.stock_movements(product_id,product_name,movement_type,quantity_change,stock_after,note,created_by) values(v_product.id,v_product.name,p_movement_type,p_quantity_change,v_new,p_note,auth.uid());
 return jsonb_build_object('product_id',v_product.id,'stock',v_new);
end; $$;
revoke all on function public.adjust_stock(uuid,integer,text,text) from public; grant execute on function public.adjust_stock(uuid,integer,text,text) to authenticated;
-- Setelah membuat akun admin pertama, jalankan: update public.profiles set role='admin' where email='EMAIL_ADMIN_ANDA';
-- Jangan pernah memasukkan service_role key ke kode frontend.
