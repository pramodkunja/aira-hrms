// Write-side payloads for the Org Chart screen's "Add org unit" and
// "Manage job templates" actions — matches web's AddUnitModal/
// ManageJobTemplatesModal (OrgUnitPayload/JobTemplatePayload) field-for-field.

class OrgUnitFormData {
  String name;
  String code;
  String? parentId; // null = top level
  String costCenter;

  OrgUnitFormData({
    this.name = '',
    this.code = '',
    this.parentId,
    this.costCenter = '',
  });

  Map<String, dynamic> toJson() => {
    'name':        name.trim(),
    'code':        code.trim().toUpperCase(),
    'parent':      parentId,
    'cost_center': costCenter.trim().toUpperCase(),
  };

  String? validate() {
    if (name.trim().isEmpty) return 'Unit name is required.';
    return null;
  }
}

class JobTemplateFormData {
  String name;
  String band;

  JobTemplateFormData({this.name = '', this.band = ''});

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'band': band.trim().toUpperCase(),
  };

  String? validate() {
    if (name.trim().isEmpty) return 'Name is required.';
    return null;
  }
}
