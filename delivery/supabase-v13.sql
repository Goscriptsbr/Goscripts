-- =====================================================================
--  GoPedido — ATUALIZAÇÃO 13: arredondamento normal do km
--  4,3 km = 4 km · 4,5 km = 4 km · 4,6 km = 5 km · abaixo de 1 km = 1 km
--  Rode DEPOIS das atualizações anteriores. Pode rodar de novo.
-- =====================================================================

create or replace function public.ff_taxa_entrega(
  p_modo text, p_km numeric, p_min numeric, p_arred boolean, p_tab jsonb, p_raio numeric, p_dist numeric)
returns numeric language plpgsql immutable as $$
declare f jsonb; d numeric;
begin
  if coalesce(p_raio, 0) > 0 and p_dist > p_raio then return null; end if;
  if p_modo = 'tabela' then
    for f in select x from jsonb_array_elements(coalesce(p_tab, '[]'::jsonb)) x
             order by (x ->> 'ate')::numeric loop
      if p_dist <= (f ->> 'ate')::numeric then return round((f ->> 'valor')::numeric, 2); end if;
    end loop;
    return null;
  end if;
  if coalesce(p_arred, true) then
    d := case when p_dist - floor(p_dist) > 0.5 then ceil(p_dist) else floor(p_dist) end;
    d := greatest(d, 1);
  else
    d := p_dist;
  end if;
  return greatest(coalesce(p_min, 0), round(d * coalesce(p_km, 0), 2));
end;
$$;
grant execute on function public.ff_taxa_entrega(text, numeric, numeric, boolean, jsonb, numeric, numeric) to anon, authenticated;
