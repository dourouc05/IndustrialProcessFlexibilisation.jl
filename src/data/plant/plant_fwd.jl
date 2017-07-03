hasRequiredEquipments(p::Plant, pr::Product) =
  ! any([! hasEquipment(p, e) for e in requiredEquipments(pr)])
