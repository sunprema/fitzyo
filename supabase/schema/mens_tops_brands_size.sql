
drop function mens_tops_brands_size; 
create or replace function mens_tops_brands_size ( retail_passport_id_input int8) 
  returns table(
    brand_id text,
    brand_name text,
    brand_website text,
    brand_description text,
    alpha_size text,
    numerical_size numeric
  ) as $$
  
  declare
  v_shirt_neck numeric;
  v_shirt_chest numeric;
  v_shirt_sleeve_length numeric;

  begin

  select 
  shirt_neck, shirt_chest, shirt_sleeve_length
  into v_shirt_neck,v_shirt_chest,v_shirt_sleeve_length
  from men_retail_passport 
  where id = retail_passport_id_input ;

  return query
  select 
  brands.id as brand_id,
  brands.brand_name as brand_name,
  brands.website as brand_website,
  brands.description as brand_description,
  btsc.alpha_size as alpha_size,
  btsc.numerical_size as numerical_size
  
  from brand_tops_size_chart btsc
  join brands on brands.id = btsc.brand_id
  
  where
  btsc.chest_low <= v_shirt_chest and v_shirt_chest < btsc.chest_high and
  btsc.neck_low <= v_shirt_neck and v_shirt_neck < btsc.neck_high  and (
  case 
    when btsc.sleeve_low > 0 and btsc.sleeve_high > 0 and v_shirt_sleeve_length > 0
    then (btsc.sleeve_low <= v_shirt_sleeve_length and v_shirt_sleeve_length < btsc.sleeve_high )
    else true
  end); 

  end;
  $$ language plpgsql;

