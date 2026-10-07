import unittest,tempfile,json,copy
from pathlib import Path
from export_cooking_rollback import compatible_copy,export
class Rollback(unittest.TestCase):
 def test_portions_and_unrelated_state(self):
  data={'v':1,'opening':{'home':{'fuel_s':99,'preservation':{'portions':[{'id':'venison_dried'}]},'storage':{'c':{'venison_raw':1},'age':{'venison_raw':10}}}},'cabins':[{'fuel_s':20,'cooking':{'portions':[{'id':'venison_cooked','remaining_s':600,'age_s':30,'shelf_s':108000},{'id':'trout_cooked','remaining_s':0,'age_s':42,'shelf_s':216000},{'id':'wolf_meat_cooked','remaining_s':90,'age_s':108000,'shelf_s':108000}]}}],'inv':{'cond':{'knife':.8}}}
  before=copy.deepcopy(data);out=compatible_copy(data);stock=out['opening']['home']['storage']
  self.assertEqual(data,before);self.assertEqual(stock['c'],{'venison_raw':2,'trout_cooked':1,'rotten_meat':1})
  self.assertEqual(stock['age']['venison_raw'],20);self.assertEqual(stock['age']['trout_cooked'],42)
  self.assertEqual(out['cabins'],[{'fuel_s':20}]);self.assertEqual(out['inv'],data['inv'])
  self.assertEqual(out['opening']['home']['preservation'],data['opening']['home']['preservation'])
 def test_legacy_and_unknown(self):
  data={'v':1,'cabins':[{'cooking':{'portions':[{'id':'venison_cooked','remaining_s':10,'age_s':3,'shelf_s':108000}]}}]}
  self.assertEqual(compatible_copy(data)['inv']['c'],{'venison_raw':1})
  with self.assertRaises(ValueError):compatible_copy({'v':2})
  with self.assertRaises(ValueError):compatible_copy({'v':1,'cabins':[{'cooking':{'portions':[{'id':'unknown'}]}}]})
 def test_exclusive_output(self):
  with tempfile.TemporaryDirectory() as d:
   a=Path(d)/'source.json';b=Path(d)/'copy.json';a.write_text(json.dumps({'v':1}));original=a.read_bytes()
   export(a,b);self.assertEqual(a.read_bytes(),original)
   with self.assertRaises(FileExistsError):export(a,b)
   with self.assertRaises(ValueError):export(a,a)
if __name__=='__main__':unittest.main()
