import { createRoot } from 'react-dom/client'
import { MemoView } from './components/MemoView'
import './styles/memo.css'

createRoot(document.getElementById('root')!).render(<MemoView />)
