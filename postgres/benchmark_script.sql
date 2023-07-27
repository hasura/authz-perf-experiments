begin;
  set role "User";
  set rls.artistID = '116';
  select * from "Track";
  reset role;
end;
