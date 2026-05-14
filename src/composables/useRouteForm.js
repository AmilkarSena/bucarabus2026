import { ref, watch } from 'vue'
import { SYSTEM_USER_ID } from '../constants/system'

/**
 * Composable para gestionar el estado y la lógica de guardado del formulario de rutas.
 */
export function useRouteForm({ props, appStore, routesStore, validateForm, validateStatusChange, getDetectedStops }) {
  const EMPTY_FORM = () => ({
    id:                 '',
    name:               '',
    color:              '#667eea',
    description:        '',
    path:               [],
    idCompany:          1,
    departureRouteSign: '',
    returnRouteSign:    '',
    firstTrip:          '',
    lastTrip:           '',
    routeFare:          0,
    isCircular:         false,
    isActive:           true,
    userCreate:         SYSTEM_USER_ID,
    userUpdate:         SYSTEM_USER_ID
  })

  const formData = ref(EMPTY_FORM())

  // Mapear props al estado del formulario
  watch(() => props.data, async (newData) => {
    if (newData && props.isEdit) {
      formData.value = {
        ...EMPTY_FORM(),
        id:                 newData.id,
        name:               newData.name               || '',
        color:              newData.color               || '#667eea',
        description:        newData.description         || '',
        path:               newData.path                || [],
        idCompany:          newData.idCompany           || '',
        departureRouteSign: newData.departureRouteSign  || '',
        returnRouteSign:    newData.returnRouteSign      || '',
        firstTrip:          newData.firstTrip            || '',
        lastTrip:           newData.lastTrip             || '',
        routeFare:          newData.fare                 ?? 0,
        isCircular:         newData.isCircular           ?? false,
        isActive:           newData.isActive             ?? true,
        userUpdate:         SYSTEM_USER_ID,
        stops:              newData.stops                || []
      }

      if (formData.value.stops.length === 0 && newData.id) {
        try {
          const freshPoints = await routesStore.getRoutePoints(newData.id)
          if (freshPoints && freshPoints.length > 0) {
            formData.value.stops = freshPoints.map(p => ({
              id_point: p.idPoint ?? p.id_point,
              name_point: p.namePoint ?? p.name_point ?? `Parada ID: ${p.idPoint ?? p.id_point}`,
              lat: parseFloat(p.lat ?? p.coordinates?.[0]),
              lng: parseFloat(p.lng ?? p.coordinates?.[1]),
              point_order: p.pointOrder ?? p.point_order
            }))
          }
        } catch (e) {
          console.warn('No se pudieron cargar stops para edicion', e)
        }
      }
    } else if (newData && newData.fromDraft) {
      formData.value = {
        ...EMPTY_FORM(),
        path:  newData.path  || [],
        stops: newData.stops || [],
        color: appStore.draftRouteColor || '#667eea'
      }
    } else if (newData && newData.path) {
      formData.value = { ...EMPTY_FORM(), path: newData.path }
    } else if (!props.isEdit) {
      formData.value = EMPTY_FORM()
    }
  }, { immediate: true })

  const handleStatusChange = async () => {
    const isValid = await validateStatusChange(formData.value.isActive, props.isEdit, props.data?.id)
    if (!isValid) {
      formData.value.isActive = true
    }
  }

  const handleSave = async () => {
    if (!validateForm(formData.value, props.isEdit)) return

    try {
      if (props.isEdit) {
        const updatePayload = {
          name:               formData.value.name.trim(),
          color:              formData.value.color,
          description:        formData.value.description?.trim() || null,
          idCompany:          formData.value.idCompany,
          departureRouteSign: formData.value.departureRouteSign?.trim() || null,
          returnRouteSign:    formData.value.returnRouteSign?.trim()    || null,
          firstTrip:          formData.value.firstTrip  || null,
          lastTrip:           formData.value.lastTrip   || null,
          routeFare:          formData.value.routeFare,
          isCircular:         formData.value.isCircular,
          userUpdate:         formData.value.userUpdate  || SYSTEM_USER_ID
        }
        await routesStore.updateRoute(props.data.id, updatePayload)
        
        if (formData.value.isActive !== props.data.isActive) {
          await routesStore.toggleRouteStatus(props.data.id, formData.value.isActive)
        }
        
        alert(`Ruta "${updatePayload.name}" actualizada exitosamente`)
      } else {
        const pointsToAssign = formData.value.stops?.length > 0 
          ? formData.value.stops.map(s => ({ id_point: s.id_point || s.idPoint }))
          : getDetectedStops().map(s => ({ id_point: s.idPoint || s.id_point }))

        const createPayload = {
          name:               formData.value.name.trim(),
          color:              formData.value.color,
          description:        formData.value.description?.trim() || null,
          path:               formData.value.path,
          idCompany:          formData.value.idCompany,
          departureRouteSign: formData.value.departureRouteSign?.trim() || null,
          returnRouteSign:    formData.value.returnRouteSign?.trim()    || null,
          firstTrip:          formData.value.firstTrip  || null,
          lastTrip:           formData.value.lastTrip   || null,
          routeFare:          formData.value.routeFare,
          isCircular:         formData.value.isCircular,
          userCreate:         formData.value.userCreate  || SYSTEM_USER_ID,
          stops:              pointsToAssign
        }
        
        const newRoute = await routesStore.addRoute(createPayload)

        if (pointsToAssign.length > 0) {
          const updated = await routesStore.getRoutePoints(newRoute.id)
          if (routesStore.routes[newRoute.id]) {
            routesStore.routes[newRoute.id].points = updated
          }
        }

        alert(`Ruta "${createPayload.name}" creada exitosamente`)
      }

      appStore.cancelRouteCreation()
      appStore.closeModal()
    } catch (error) {
      console.error('Error guardando ruta:', error)
      alert(error.message || 'Error al guardar la ruta')
    }
  }

  const handleCancel = () => {
    appStore.cancelRouteCreation()
    appStore.closeModal()
  }

  return { formData, handleStatusChange, handleSave, handleCancel }
}
