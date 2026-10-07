import {lazy,Suspense,type ComponentProps} from 'react';
const Implementation=lazy(()=>import('./Editor').then(m=>({default:m.Editor})));
export function Editor(props:ComponentProps<typeof Implementation>){return <Suspense fallback={<div className="loading">Preparando el editor…</div>}><Implementation {...props}/></Suspense>}
