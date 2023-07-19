
const AI_STYLERS = ['zebra', 'peacock', 'lion', 'leopard']

const AIModel = ({params}) => {
    
    if( AI_STYLERS.includes(params.modelName)){
        return <h1>{params.modelName}</h1>
    }else{
        throw new Error(`Model name ${params.modelName} is not valid`);
    }
    
}

export default AIModel ;