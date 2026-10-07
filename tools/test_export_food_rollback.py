import json,tempfile,unittest
from pathlib import Path
from export_food_rollback import compatible_copy,export
class FoodSaveCopyTests(unittest.TestCase):
 def fixture(self):
  return {'v':1,'clock':{'total':90000},'inv':{'counts':{'venison_dried':2,'venison_cooked':1,'knife':1},'age':{'venison_dried':120*3600,'venison_cooked':0},'cond':{'knife':.7}},'opening':{'state':{'battery_wh':17},'home':{'fuel_s':2000,'storage':{'c':{'beans':1}},'preservation':{'portions':[{'id':'trout_dried','remaining_s':3600,'age_s':30*3600,'shelf_s':60*3600},{'id':'rotten_meat','remaining_s':0}]}}},'pickups':[{'id':'whitefish_dried','n':1,'age_s':120*3600}]}
 def test_conversion_preserves_energy_age_and_nonfood_state(self):
  data=self.fixture();before=json.dumps(data,sort_keys=True);out=compatible_copy(data)
  self.assertEqual(before,json.dumps(data,sort_keys=True));self.assertEqual(out['clock'],data['clock']);self.assertEqual(out['inv']['cond'],data['inv']['cond'])
  self.assertEqual(out['inv']['counts'],{'venison_cooked':3,'knife':1});self.assertEqual(out['inv']['age']['venison_cooked'],24*3600)
  home=out['opening']['home'];self.assertEqual(home['fuel_s'],2000);self.assertNotIn('preservation',home)
  self.assertEqual(home['storage']['c'],{'beans':1,'trout_cooked':1,'rotten_meat':1});self.assertEqual(home['storage']['age']['trout_cooked'],30*3600)
  self.assertEqual(out['pickups'][0],{'id':'whitefish_cooked','n':1,'age_s':30*3600});self.assertEqual(out['opening']['state']['battery_wh'],17)
 def test_refuses_overwrite(self):
  with tempfile.TemporaryDirectory() as folder:
   source=Path(folder)/'source.json';dest=Path(folder)/'copy.json';source.write_text(json.dumps(self.fixture()),encoding='utf8');original=source.read_bytes()
   with self.assertRaises(ValueError):export(source,source)
   export(source,dest);self.assertEqual(source.read_bytes(),original)
   with self.assertRaises(FileExistsError):export(source,dest)
 def test_rejects_unknown_save_versions(self):
  with self.assertRaises(ValueError):compatible_copy({'v':2})
  with self.assertRaises(ValueError):compatible_copy([])
if __name__=='__main__':unittest.main()
