import json,tempfile,unittest
from pathlib import Path
from export_electrical_rollback import compatible_copy,export

class CompatibleSaveTests(unittest.TestCase):
 def fixture(self):
  return {'v':1,'clock':{'total':91234,'base_time_scale':30},'player':{'hp':81},'inv':{'counts':{'beans':2,'winter_controller':1},'age':{'beans':17},'cond':{'knife':.6,'dc_fuse':1}},'chests':[{'c':{'wood':3,'dc_cable':1}}],'first_week':{'cache':{'c':{'bandage':2,'sealed_connector':1}},'feeder_isolated':True},'opening':{'home':{'electrical':{'packet_claimed':True},'storage':{'c':{'dc_fuse':1,'matches':3}}},'state':{'battery_wh':19,'grid_fail_s':0,'solar':{'enabled':True,'controller_ok':True,'snow_cover':.4,'winter_controller':True,'tested_lead_installed':True,'fuse_ok':True,'cable_ok':True}}},'pickups':[{'id':'dc_fuse','n':1},{'id':'axe','n':1,'c':.3}]}
 def test_removes_only_new_component_state(self):
  data=self.fixture();original=json.dumps(data,sort_keys=True);out=compatible_copy(data)
  self.assertEqual(json.dumps(data,sort_keys=True),original)
  self.assertEqual(out['inv']['counts'],{'beans':2});self.assertEqual(out['inv']['cond'],{'knife':.6})
  self.assertEqual(out['chests'][0]['c'],{'wood':3});self.assertEqual(out['first_week']['cache']['c'],{'bandage':2})
  self.assertEqual(out['opening']['home']['storage']['c'],{'matches':3});self.assertNotIn('electrical',out['opening']['home'])
  self.assertEqual(out['opening']['state']['solar'],{'enabled':True,'controller_ok':True,'snow_cover':.4})
  self.assertEqual(out['opening']['state']['battery_wh'],19);self.assertEqual(out['clock'],data['clock'])
  self.assertEqual(out['pickups'],[{'id':'axe','n':1,'c':.3}]);self.assertTrue(out['first_week']['feeder_isolated'])
 def test_export_cannot_overwrite_input_or_existing_output(self):
  with tempfile.TemporaryDirectory() as folder:
   source=Path(folder)/'original.json';dest=Path(folder)/'copy.json';source.write_text(json.dumps(self.fixture()),encoding='utf-8');before=source.read_bytes()
   with self.assertRaises(ValueError):export(source,source)
   export(source,dest);self.assertEqual(source.read_bytes(),before);result=dest.read_bytes()
   with self.assertRaises(FileExistsError):export(source,dest)
   self.assertEqual(dest.read_bytes(),result)
 def test_rejects_unknown_save_versions(self):
  with self.assertRaises(ValueError):compatible_copy({'v':2})
  with self.assertRaises(ValueError):compatible_copy([])

if __name__=='__main__':unittest.main()
